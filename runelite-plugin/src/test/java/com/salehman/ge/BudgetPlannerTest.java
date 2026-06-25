package com.salehman.ge;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import org.junit.Test;

/** Pins the greedy budget allocation (buy-limit-aware, capital-bound, ranked order). */
public class BudgetPlannerTest
{
	/** Build real FlipItems via the ranker so realizedGpPerHour etc. are populated. */
	private List<FlipItem> flips()
	{
		Map<Integer, GrandExchangeApi.Latest> latest = new HashMap<>();
		Map<Integer, GrandExchangeApi.Mapping> mapping = new HashMap<>();
		Map<Integer, GrandExchangeApi.Volume> volumes = new HashMap<>();
		// A: buy 100, sell 130 → tax 2, postTax 28, limit 10.
		latest.put(1, latest(130, 100));
		mapping.put(1, mapping(1, "A", 10, false));
		volumes.put(1, volume(5000, 5000));
		// B: buy 1000, sell 1100 → tax 22, postTax 78, limit 5.
		latest.put(2, latest(1100, 1000));
		mapping.put(2, mapping(2, "B", 5, false));
		volumes.put(2, volume(5000, 5000));
		// Rank by POTENTIAL_PROFIT so order is deterministic & known: A potential 280, B 390 → B,A.
		return FlipFinder.rank(latest, volumes, mapping, config(0, 100, SalehmanGeConfig.SortBy.POTENTIAL_PROFIT), 1_000_000L);
	}

	@Test
	public void allocatesInRankedOrderRespectingLimitAndBudget()
	{
		List<FlipItem> flips = flips();          // order: B (potential 390), then A (280)
		assertEquals("B", flips.get(0).name);
		// Budget 7000: B costs 1000×5=5000 (full limit), leaving 2000 → A costs 100×10=1000 (full limit), 1000 left over.
		BudgetPlanner.BudgetPlan plan = BudgetPlanner.plan(flips, 7000);
		assertEquals(2, plan.allocations.size());
		assertEquals("B", plan.allocations.get(0).flip.name);
		assertEquals(5, plan.allocations.get(0).quantity);          // capped at buy limit 5
		assertEquals(5000, plan.allocations.get(0).capital);
		assertEquals(390, plan.allocations.get(0).profit);          // 5 × 78
		assertEquals("A", plan.allocations.get(1).flip.name);
		assertEquals(10, plan.allocations.get(1).quantity);         // capped at buy limit 10
		assertEquals(1000, plan.allocations.get(1).capital);
		assertEquals(280, plan.allocations.get(1).profit);          // 10 × 28
		assertEquals(6000, plan.capitalUsed);                       // 1000 left unspent (couldn't fill more)
		assertEquals(670, plan.totalProfit);                       // 390 + 280
	}

	@Test
	public void capitalBoundWhenBudgetSmallerThanLimit()
	{
		List<FlipItem> flips = flips();          // B first
		// Budget 2500: B affordable 2 (2×1000=2000), leaving 500 → A affordable 5 (5×100=500).
		BudgetPlanner.BudgetPlan plan = BudgetPlanner.plan(flips, 2500);
		assertEquals(2, plan.allocations.size());
		assertEquals(2, plan.allocations.get(0).quantity);         // capital-bound, under the limit of 5
		assertEquals(5, plan.allocations.get(1).quantity);         // 500 / 100
		assertEquals(2500, plan.capitalUsed);
		assertEquals(2 * 78 + 5 * 28, plan.totalProfit);
	}

	@Test
	public void emptyWhenBudgetCannotAffordAnything()
	{
		BudgetPlanner.BudgetPlan plan = BudgetPlanner.plan(flips(), 50); // cheapest buy is 100
		assertTrue(plan.allocations.isEmpty());
		assertEquals(0, plan.capitalUsed);
		assertEquals(0, plan.totalProfit);
	}

	// --- helpers (mirror FlipFinderTest) ---

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
}
