package com.salehman.ge;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import org.junit.Test;

/**
 * Pins the GE tax math and the flip ranking/filtering. Pure inputs — no network,
 * no RuneLite client needed at runtime (only the config interface, stubbed inline).
 */
public class FlipFinderTest
{
	private SalehmanGeConfig config(int minMargin, int minVolume)
	{
		return new SalehmanGeConfig()
		{
			@Override
			public int minMargin()
			{
				return minMargin;
			}

			@Override
			public int minVolume()
			{
				return minVolume;
			}
		};
	}

	private GrandExchangeApi.Latest latest(int high, int low)
	{
		GrandExchangeApi.Latest l = new GrandExchangeApi.Latest();
		l.high = high;
		l.low = low;
		return l;
	}

	private GrandExchangeApi.Mapping mapping(int id, String name, int limit, boolean members)
	{
		GrandExchangeApi.Mapping m = new GrandExchangeApi.Mapping();
		m.id = id;
		m.name = name;
		m.limit = limit;
		m.members = members;
		return m;
	}

	private GrandExchangeApi.Volume volume(long hi, long lo)
	{
		GrandExchangeApi.Volume v = new GrandExchangeApi.Volume();
		v.highPriceVolume = hi;
		v.lowPriceVolume = lo;
		return v;
	}

	@Test
	public void taxIsPercentBasedCappedAndExemptUnderFifty()
	{
		SalehmanGeConfig c = config(0, 0);
		assertEquals(0, FlipFinder.geTax(49, c));                      // under 50 gp → no tax
		assertEquals(2, FlipFinder.geTax(100, c));                     // 2% of 100 (live OSRS rate)
		assertEquals(5_000_000, FlipFinder.geTax(1_000_000_000, c));   // capped at 5M
	}

	@Test
	public void ranksByPotentialProfitAndFiltersThinVolume()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();

		// A: margin 100, limit 1000 → biggest potential.
		latest.put(1, latest(1100, 1000));
		mapping.put(1, mapping(1, "A", 1000, false));
		volumes.put(1, volume(5000, 5000));
		// B: same margin, limit 100 → smaller potential.
		latest.put(2, latest(1100, 1000));
		mapping.put(2, mapping(2, "B", 100, false));
		volumes.put(2, volume(5000, 5000));
		// C: zero volume → filtered out by minVolume.
		latest.put(3, latest(2000, 1000));
		mapping.put(3, mapping(3, "C", 1000, false));
		volumes.put(3, volume(0, 0));

		// Synthetic items have null timestamps → ageSeconds -1 → staleness filter is a no-op.
		// Pin the sort to POTENTIAL_PROFIT explicitly (the config default is now REALIZED_VELOCITY).
		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping,
			config(0, 100, SalehmanGeConfig.SortBy.POTENTIAL_PROFIT), 1_000_000L);
		assertEquals(2, flips.size());
		assertEquals("A", flips.get(0).name);   // higher profit/limit ranks first
		assertEquals("B", flips.get(1).name);
	}

	@Test
	public void velocitySortRanksByGpPerHour()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();

		// A: sell 1100 / buy 1000 → tax 22 (2%), postTax 78, limit 1000 → 78000 ÷ 4h = 19500 gp/hr.
		latest.put(1, latest(1100, 1000));
		mapping.put(1, mapping(1, "A", 1000, false));
		volumes.put(1, volume(5000, 5000));
		// B: sell 130 / buy 100 → tax 2 (2%), postTax 28, limit 10000 → 280000 ÷ 4h = 70000 gp/hr.
		latest.put(2, latest(130, 100));
		mapping.put(2, mapping(2, "B", 10000, false));
		volumes.put(2, volume(5000, 5000));

		SalehmanGeConfig c = new SalehmanGeConfig()
		{
			@Override
			public int minMargin()
			{
				return 0;
			}

			@Override
			public int minVolume()
			{
				return 100;
			}

			@Override
			public SortBy sortBy()
			{
				return SortBy.VELOCITY;
			}
		};
		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping, c, 1_000_000L);
		assertEquals(2, flips.size());
		assertEquals("B", flips.get(0).name);                  // 70000 gp/hr beats 19500 (fast turnover)
		assertEquals(70000.0, flips.get(0).gpPerHour, 1e-9);
		assertEquals(19500.0, flips.get(1).gpPerHour, 1e-9);
	}

	@Test
	public void surfacedNumbersAreNetOfTax()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();
		latest.put(1, latest(1100, 1000));                 // gross spread 100
		mapping.put(1, mapping(1, "A", 100, false));
		volumes.put(1, volume(5000, 5000));

		FlipItem f = FlipFinder.rank(latest, volumes, mapping, config(0, 100), 1_000_000L).get(0);
		assertEquals(100, f.margin);                       // gross
		assertEquals(22, f.tax);                           // 2% of 1100
		assertEquals(78, f.postTaxMargin);                 // NET per item
		assertEquals(7.8, f.roi, 1e-9);                    // net / buy, %
		assertEquals(7800, f.potentialProfit);             // net × limit
		assertEquals(1950.0, f.gpPerHour, 1e-9);           // potential / 4h
		// the honesty guarantee: every aggregate is derived from the NET margin, never gross
		assertEquals((long) f.postTaxMargin * f.buyLimit, f.potentialProfit);
		assertEquals((double) f.postTaxMargin / f.buyPrice * 100.0, f.roi, 1e-9);
	}

	@Test
	public void fillConfidenceDecaysFromFreshToFloor()
	{
		assertEquals(1.0, FlipFinder.fillConfidence(-1), 1e-9);       // unknown age → full confidence
		assertEquals(1.0, FlipFinder.fillConfidence(0), 1e-9);        // brand new
		assertEquals(1.0, FlipFinder.fillConfidence(90), 1e-9);       // edge of the fresh window
		assertEquals(0.7542, FlipFinder.fillConfidence(3600), 1e-3);  // ~1h → ~0.75 (backlog target)
		assertEquals(0.75, FlipFinder.fillConfidence(3660), 1e-9);    // exact t=1/3 crossover → 0.75
		assertEquals(0.25, FlipFinder.fillConfidence(10800), 1e-9);   // 3h → floor exactly
		assertEquals(0.25, FlipFinder.fillConfidence(20000), 1e-9);   // beyond floor stays clamped
	}

	@Test
	public void realizedVelocityDownranksStaleFatFlip()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();
		long now = 100_000L;

		// A: fresh (30s old). postTax 28, limit 10000 → 70000 gp/hr theoretical, conf 1.0.
		latest.put(1, latest(130, 100, now - 30, now - 30));
		mapping.put(1, mapping(1, "A", 10000, false));
		volumes.put(1, volume(5000, 5000));
		// B: stale (3h old). postTax 78, limit 10257 → ~200011 gp/hr theoretical BUT conf 0.25
		// → ~50003 realized, which loses to A's 70000.
		latest.put(2, latest(1100, 1000, now - 10800, now - 10800));
		mapping.put(2, mapping(2, "B", 10257, false));
		volumes.put(2, volume(5000, 5000));

		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping, configRealizedNoStaleFilter(), now);
		assertEquals(2, flips.size());
		assertEquals("A", flips.get(0).name);                  // fresh realized 70000 beats stale 50003
		assertEquals("B", flips.get(1).name);
		assertEquals(1.0, flips.get(0).fillConfidence, 1e-9);
		assertEquals(0.25, flips.get(1).fillConfidence, 1e-9);
		assertEquals(70000.0, flips.get(0).realizedGpPerHour, 1e-6);  // fresh: realized == theoretical
	}

	@Test
	public void realizedEqualsTheoreticalWhenTimestampsMissing()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();
		latest.put(1, latest(1100, 1000));     // null timestamps → ageSeconds -1 → confidence 1.0
		mapping.put(1, mapping(1, "A", 1000, false));
		volumes.put(1, volume(5000, 5000));

		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping, config(0, 100), 1_000_000L);
		assertEquals(1, flips.size());
		assertEquals(1.0, flips.get(0).fillConfidence, 1e-9);
		assertEquals(flips.get(0).gpPerHour, flips.get(0).realizedGpPerHour, 1e-9);
	}

	@Test
	public void mappingCacheHasTtlAndDoesNotCacheEmptyResults() throws Exception
	{
		Map<Integer, GrandExchangeApi.Mapping> good = new HashMap<>();
		good.put(1, mapping(1, "A", 10, false));
		final int[] calls = {0};
		GrandExchangeApi api = new GrandExchangeApi(null, null)
		{
			@Override
			public Map<Integer, GrandExchangeApi.Mapping> mapping()
			{
				calls[0]++;
				return calls[0] == 1 ? good : new HashMap<>(); // 1st good, then empty
			}
		};
		FlipFinder ff = new FlipFinder(api);
		assertEquals(1, ff.getMapping(0L).size());                 // first fetch
		assertEquals(1, calls[0]);
		assertEquals(1, ff.getMapping(1000L).size());              // within TTL → served from cache
		assertEquals(1, calls[0]);                                 // no extra fetch
		// TTL expired → refetch returns EMPTY → must NOT poison the cache; keep the stale-good one.
		assertEquals(1, ff.getMapping(FlipFinder.MAPPING_TTL_MS + 1L).size());
		assertEquals(2, calls[0]);
	}

	@Test
	public void alchProfitAndGpPerHourFromHighalchAndNaturePrice()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();
		// Nature rune (id 561): instant-buy 100 → cost per alch cast.
		latest.put(FlipFinder.NATURE_RUNE_ID, latest(100, 90));
		// A flip that is ALSO alchable: buy 35000 / sell 36000 → postTax 280/item, but highalch 38000.
		latest.put(1, latest(36000, 35000));
		GrandExchangeApi.Mapping m = mapping(1, "Rune platebody", 70, true);
		m.highalch = 38000;
		mapping.put(1, m);
		volumes.put(1, volume(5000, 5000));

		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping, config(0, 100), 1_000_000L);
		FlipItem f = flips.stream().filter(x -> x.id == 1).findFirst().orElseThrow(AssertionError::new);
		assertEquals(2900, f.alchProfit);                                    // 38000 − 100 nature − 35000 item
		assertEquals(2900.0 * FlipFinder.ALCH_CASTS_PER_HOUR, f.alchGpPerHour, 1e-6);
		assertTrue("alch should still beat this thin flip", f.alchGpPerHour > f.realizedGpPerHour);
	}

	@Test
	public void alchZeroWhenItemCostExceedsHighalch()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();
		latest.put(FlipFinder.NATURE_RUNE_ID, latest(100, 90));
		// buy 1000 but highalch only 900 → 900 − 100 − 1000 < 0 → alch is a net loss → 0.
		latest.put(1, latest(1100, 1000));
		GrandExchangeApi.Mapping m = mapping(1, "A", 1000, false);
		m.highalch = 900;
		mapping.put(1, m);
		volumes.put(1, volume(5000, 5000));

		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping, config(0, 100), 1_000_000L);
		assertEquals(0, flips.get(0).alchProfit);
		assertEquals(0.0, flips.get(0).alchGpPerHour, 1e-9);
	}

	@Test
	public void alchZeroWhenNotAlchableOrNoNaturePrice()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();
		// No nature rune entry → naturePrice 0 → alch disabled even though highalch is set.
		latest.put(1, latest(1100, 1000));
		GrandExchangeApi.Mapping m = mapping(1, "A", 1000, false);
		m.highalch = 5000;
		mapping.put(1, m);
		volumes.put(1, volume(5000, 5000));

		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping, config(0, 100), 1_000_000L);
		assertEquals(0, flips.get(0).alchProfit);
		assertEquals(0.0, flips.get(0).alchGpPerHour, 1e-9);
	}

	// --- additional helpers ---

	private SalehmanGeConfig config(int minMargin, int minVolume, SalehmanGeConfig.SortBy sort)
	{
		return new SalehmanGeConfig()
		{
			@Override
			public int minMargin()
			{
				return minMargin;
			}

			@Override
			public int minVolume()
			{
				return minVolume;
			}

			@Override
			public SortBy sortBy()
			{
				return sort;
			}
		};
	}

	private GrandExchangeApi.Latest latest(int high, int low, long highTime, long lowTime)
	{
		GrandExchangeApi.Latest l = latest(high, low);
		l.highTime = highTime;
		l.lowTime = lowTime;
		return l;
	}

	private SalehmanGeConfig configRealizedNoStaleFilter()
	{
		return new SalehmanGeConfig()
		{
			@Override
			public int minMargin()
			{
				return 0;
			}

			@Override
			public int minVolume()
			{
				return 100;
			}

			@Override
			public SortBy sortBy()
			{
				return SortBy.REALIZED_VELOCITY;
			}

			@Override
			public int maxStaleMinutes()
			{
				return 0;   // don't hard-filter the 3h-old flip; the point is to RANK it low
			}
		};
	}
}
