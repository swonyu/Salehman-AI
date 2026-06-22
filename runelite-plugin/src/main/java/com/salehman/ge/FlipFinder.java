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

	private final GrandExchangeApi api;
	// volatile: the panel triggers refresh on background threads, so the lazy init
	// can race — publish the fully-built map atomically (a rare double-fetch is benign).
	private volatile Map<Integer, GrandExchangeApi.Mapping> mappingCache;

	@Inject
	FlipFinder(GrandExchangeApi api)
	{
		this.api = api;
	}

	public List<FlipItem> findFlips(SalehmanGeConfig config) throws IOException
	{
		Map<Integer, GrandExchangeApi.Mapping> mapping = mappingCache;
		if (mapping == null)
		{
			mapping = api.mapping();               // ~static; fetch once
			mappingCache = mapping;
		}
		Map<Integer, GrandExchangeApi.Latest> latest = api.latest();
		Map<Integer, GrandExchangeApi.Volume> volumes = api.volumes();
		return rank(latest, volumes, mapping, config, System.currentTimeMillis() / 1000L);
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

			flips.add(new FlipItem(id, m.name, buyPrice, sellPrice, margin, tax, postTax,
				roi, limit, volume, potential, gpPerHour, m.members, ageSeconds));
		}

		flips.sort(comparator(config.sortBy()));
		int max = Math.max(1, config.maxResults());
		return flips.size() > max ? new ArrayList<>(flips.subList(0, max)) : flips;
	}

	private static Comparator<FlipItem> comparator(SalehmanGeConfig.SortBy sortBy)
	{
		switch (sortBy)
		{
			case ROI:
				return Comparator.comparingDouble((FlipItem f) -> f.roi).reversed();
			case MARGIN:
				return Comparator.comparingInt((FlipItem f) -> f.postTaxMargin).reversed();
			case VELOCITY:
				return Comparator.comparingDouble((FlipItem f) -> f.gpPerHour).reversed();
			case POTENTIAL_PROFIT:
			default:
				return Comparator.comparingLong((FlipItem f) -> f.potentialProfit).reversed();
		}
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
