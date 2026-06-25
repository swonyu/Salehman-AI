package com.salehman.ge;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import javax.inject.Inject;
import javax.inject.Singleton;

/**
 * Joins live prices + volume + item mapping and ranks the best Grand Exchange
 * flips, applying the GE sell tax. Pure-ish (the only side effect is caching the
 * static-ish item mapping). Deterministic given the same API snapshot, so it's
 * unit-tested in {@code FlipFinderTest}.
 */
@Singleton
public class FlipFinder
{
	// GE buy limits reset every 4 hours — the window the gp/hour velocity is spread over.
	static final double GE_WINDOW_HOURS = 4.0;

	// Item mapping is near-static; cache it but re-fetch occasionally (new items ship).
	static final long MAPPING_TTL_MS = 6L * 60 * 60 * 1000; // 6h

	private final GrandExchangeApi api;
	// volatile: the panel triggers refresh on background threads, so the lazy init
	// can race — publish the fully-built map atomically (a rare double-fetch is benign).
	private volatile Map<Integer, GrandExchangeApi.Mapping> mappingCache;
	private volatile long mappingFetchedAtMs;

	@Inject
	FlipFinder(GrandExchangeApi api)
	{
		this.api = api;
	}

	public List<FlipItem> findFlips(SalehmanGeConfig config) throws IOException
	{
		Map<Integer, GrandExchangeApi.Mapping> mapping = getMapping(System.currentTimeMillis());
		Map<Integer, GrandExchangeApi.Latest> latest = api.latest();
		Map<Integer, GrandExchangeApi.Volume> volumes = api.volumes();
		return rank(latest, volumes, mapping, config, System.currentTimeMillis() / 1000L);
	}

	/**
	 * Cached item mapping with a TTL and an empty-result guard. The old code cached the
	 * first fetch forever — and an empty/failed fetch would have poisoned the cache
	 * permanently. Here we only replace the cache with a NON-empty result, and fall back
	 * to the stale-but-usable cache if a refresh comes back empty. {@code nowMs} is a
	 * parameter so the TTL is unit-testable. Package-private for the test.
	 */
	Map<Integer, GrandExchangeApi.Mapping> getMapping(long nowMs) throws IOException
	{
		Map<Integer, GrandExchangeApi.Mapping> cached = mappingCache;
		if (cached != null && !cached.isEmpty() && nowMs - mappingFetchedAtMs < MAPPING_TTL_MS)
		{
			return cached;
		}
		try
		{
			Map<Integer, GrandExchangeApi.Mapping> fresh = api.mapping();
			if (fresh != null && !fresh.isEmpty())
			{
				mappingCache = fresh;
				mappingFetchedAtMs = nowMs;
				return fresh;
			}
		}
		catch (IOException e)
		{
			// The real failure mode is a thrown IOException (HTTP error / malformed body),
			// not an empty return. Don't discard a good cached mapping over a transient blip.
			if (cached != null && !cached.isEmpty())
			{
				return cached;
			}
			throw e;
		}
		// Refresh returned empty (no cache to fall back on): serve nothing rather than poison.
		return cached != null ? cached : java.util.Collections.emptyMap();
	}

	/** Pure ranking — separated from I/O so it can be tested with fixed inputs.
	 *  `nowSeconds` is passed in (not read from the clock) so the staleness filter
	 *  is deterministic and unit-testable. */
	static List<FlipItem> rank(
		Map<Integer, GrandExchangeApi.Latest> latest,
		Map<Integer, GrandExchangeApi.Volume> volumes,
		Map<Integer, GrandExchangeApi.Mapping> mapping,
		SalehmanGeConfig config,
		long nowSeconds)
	{
		List<FlipItem> flips = new ArrayList<>();
		// Nature rune instant-buy price (what an alch cast costs) — for the alch-vs-flip compare.
		GrandExchangeApi.Latest nature = latest.get(NATURE_RUNE_ID);
		int naturePrice = (nature != null && nature.high != null) ? nature.high : 0;
		for (Map.Entry<Integer, GrandExchangeApi.Latest> e : latest.entrySet())
		{
			int id = e.getKey();
			GrandExchangeApi.Latest l = e.getValue();
			GrandExchangeApi.Mapping m = mapping.get(id);
			if (m == null || l == null || l.high == null || l.low == null)
			{
				continue;
			}
			int sellPrice = l.high;   // instant-buy — where your sell offer fills
			int buyPrice = l.low;     // instant-sell — where your buy offer fills
			if (sellPrice <= 0 || buyPrice <= 0 || sellPrice < buyPrice)
			{
				continue;
			}

			long volume = 0;
			GrandExchangeApi.Volume v = volumes.get(id);
			if (v != null)
			{
				volume = (v.highPriceVolume == null ? 0 : v.highPriceVolume)
					+ (v.lowPriceVolume == null ? 0 : v.lowPriceVolume);
			}

			int tax = geTax(sellPrice, config);
			int margin = sellPrice - buyPrice;
			int postTax = margin - tax;
			int limit = m.limit == null ? 0 : m.limit;
			double roi = buyPrice > 0 ? (double) postTax / buyPrice * 100.0 : 0.0;
			long potential = (long) postTax * Math.max(limit, 0);
			// gp/hour money-velocity: a full buy-limit window of post-tax profit spread
			// over the 4h reset (0 when the limit is unknown). Mirrors StockSageGEFlip.
			double gpPerHour = potential / GE_WINDOW_HOURS;

			if (postTax < config.minMargin())
			{
				continue;
			}
			if (volume < config.minVolume())
			{
				continue;
			}
			if (buyPrice < config.minPrice())
			{
				continue;
			}
			if (config.maxPrice() > 0 && sellPrice > config.maxPrice())
			{
				continue;
			}
			if (config.membersOnly() && !m.members)
			{
				continue;
			}

			// Freshness: a flip needs BOTH legs trading recently. Use the OLDER leg
			// (the limiting factor) so a half-stale spread is correctly skipped.
			long oldest = oldestTradedTimestamp(l);
			long ageSeconds = oldest > 0 ? Math.max(0, nowSeconds - oldest) : -1;
			if (config.maxStaleMinutes() > 0 && ageSeconds >= 0
				&& ageSeconds > (long) config.maxStaleMinutes() * 60L)
			{
				continue;
			}

			// Discount the theoretical gp/hour by how fresh the quotes are: a stale spread
			// is the #1 reason a flip looks great but never fills. realizedGpPerHour is what
			// the REALIZED_VELOCITY sort ranks on. Proxy for fill-probability, not a promise.
			double confidence = fillConfidence(ageSeconds);
			double realizedGpPerHour = gpPerHour * confidence;

			// Alchemy alternative: profit per cast = highalch − nature price (≥0), gp/hour at a
			// sustained cast rate. 0 when the item can't be alched at a profit or data is missing.
			int alchProfit = 0;
			double alchGpPerHour = 0;
			if (m.highalch != null && naturePrice > 0)
			{
				// Alch DESTROYS the item: profit = highalch − nature cost − the item you buy
				// (buyPrice = your buy-offer fill, consistent with the flip's own margin).
				int perCast = m.highalch - naturePrice - buyPrice;
				if (perCast > 0)
				{
					alchProfit = perCast;
					alchGpPerHour = (double) perCast * ALCH_CASTS_PER_HOUR;
				}
			}

			flips.add(new FlipItem(id, m.name, buyPrice, sellPrice, margin, tax, postTax,
				roi, limit, volume, potential, gpPerHour, realizedGpPerHour, confidence,
				alchProfit, alchGpPerHour, m.members, ageSeconds));
		}

		flips.sort(comparator(config.sortBy()));
		// Return the FULL ranked list — the panel caps how many ROWS it shows (config
		// maxResults), but the budget allocator considers every flip, not just the top N.
		return flips;
	}

	private static Comparator<FlipItem> comparator(SalehmanGeConfig.SortBy sortBy)
	{
		// Tie-break by id so ranking is deterministic — HashMap iteration order is not,
		// so equal-keyed flips would otherwise shuffle between refreshes (and tests).
		Comparator<FlipItem> tie = Comparator.comparingInt((FlipItem f) -> f.id);
		switch (sortBy)
		{
			case ROI:
				return Comparator.comparingDouble((FlipItem f) -> f.roi).reversed().thenComparing(tie);
			case MARGIN:
				return Comparator.comparingInt((FlipItem f) -> f.postTaxMargin).reversed().thenComparing(tie);
			case VELOCITY:
				return Comparator.comparingDouble((FlipItem f) -> f.gpPerHour).reversed().thenComparing(tie);
			case REALIZED_VELOCITY:
				return Comparator.comparingDouble((FlipItem f) -> f.realizedGpPerHour).reversed().thenComparing(tie);
			case POTENTIAL_PROFIT:
			default:
				return Comparator.comparingLong((FlipItem f) -> f.potentialProfit).reversed().thenComparing(tie);
		}
	}

	/**
	 * Fill-confidence from quote age: 1.0 when fresh (≤90s) or age unknown (-1), then a
	 * LINEAR decay to a 0.25 floor reached at ~3h. A time-decay PROXY for "will this
	 * actually fill?", not a volume measurement — a 3h-old Bonds quote may still fill
	 * instantly. Pure + deterministic. Mirrors OSRS_BACKLOG #1.
	 */
	static final double FRESH_SECONDS = 90.0;
	static final double FLOOR_AGE_SECONDS = 3 * 3600.0; // 10800s = 3h
	static final double CONFIDENCE_FLOOR = 0.25;

	// Alchemy compare: nature rune item id + a sustained High Alchemy cast rate (estimate;
	// real throughput is attention-gated and varies with method).
	static final int NATURE_RUNE_ID = 561;
	static final int ALCH_CASTS_PER_HOUR = 1200;

	static double fillConfidence(long ageSeconds)
	{
		if (ageSeconds < 0 || ageSeconds <= FRESH_SECONDS)
		{
			return 1.0;
		}
		if (ageSeconds >= FLOOR_AGE_SECONDS)
		{
			return CONFIDENCE_FLOOR;
		}
		double t = (ageSeconds - FRESH_SECONDS) / (FLOOR_AGE_SECONDS - FRESH_SECONDS);
		return 1.0 + t * (CONFIDENCE_FLOOR - 1.0); // 1.0 → 0.25
	}

	/**
	 * OSRS Grand Exchange sell tax: a percentage of the sell price (default 2%, the
	 * live rate since 2025-05-29), capped per item (default 5,000,000 gp), with no
	 * tax on items under 50 gp. Rate + cap are configurable since Jagex tunes them.
	 */
	/** Epoch-seconds of the OLDER of the two quote legs — the limiting factor for a
	 *  two-sided flip. -1 if either leg's time is unknown (can't judge freshness). */
	private static long oldestTradedTimestamp(GrandExchangeApi.Latest l)
	{
		if (l.highTime == null || l.lowTime == null)
		{
			return -1;
		}
		return Math.min(l.highTime, l.lowTime);
	}

	static int geTax(int sellPrice, SalehmanGeConfig config)
	{
		if (sellPrice < 50)
		{
			return 0;
		}
		long tax = (long) Math.floor(sellPrice * (config.taxPercent() / 100.0));
		return (int) Math.min(tax, Math.max(0, config.taxCap()));
	}
}
