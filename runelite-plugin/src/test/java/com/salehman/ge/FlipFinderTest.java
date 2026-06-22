package com.salehman.ge;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static org.junit.Assert.assertEquals;
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
		List<FlipItem> flips = FlipFinder.rank(latest, volumes, mapping, config(0, 100), 1_000_000L);
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
}
