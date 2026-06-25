package com.salehman.ge;

import java.util.ArrayList;
import java.util.List;

/**
 * Greedy, buy-limit-aware capital allocator: "I have N gp — what do I buy, and how
 * much do I make?" Walks the already-ranked flips highest-first, buying up to each
 * item's 4h buy limit (or until the budget runs out), so the user's gp goes to the
 * best opportunities first. Pure + deterministic, so it's unit-tested.
 *
 * Honesty: like every number here, this assumes your offers actually FILL at the quoted
 * prices and within the buy limits. It's an upper-bound plan, not a guarantee.
 */
public final class BudgetPlanner
{
	private BudgetPlanner()
	{
	}

	/** One line of the plan: buy {@code quantity} of {@code flip} for {@code capital}, make {@code profit}. */
	public static final class Allocation
	{
		public final FlipItem flip;
		public final int quantity;
		public final long capital;   // quantity * buyPrice
		public final long profit;    // quantity * postTaxMargin

		Allocation(FlipItem flip, int quantity, long capital, long profit)
		{
			this.flip = flip;
			this.quantity = quantity;
			this.capital = capital;
			this.profit = profit;
		}
	}

	/** The allocation across a budget, with totals. */
	public static final class BudgetPlan
	{
		public final List<Allocation> allocations;
		public final long budget;
		public final long capitalUsed;
		public final long totalProfit;
		public final double realizedGpPerHour;   // sum of per-allocation realized velocity (limit-fill scaled)

		BudgetPlan(List<Allocation> allocations, long budget, long capitalUsed,
			long totalProfit, double realizedGpPerHour)
		{
			this.allocations = allocations;
			this.budget = budget;
			this.capitalUsed = capitalUsed;
			this.totalProfit = totalProfit;
			this.realizedGpPerHour = realizedGpPerHour;
		}
	}

	/**
	 * Allocate {@code budget} gp across {@code rankedFlips} in their given order, buying up
	 * to each item's buy limit. Items with no margin or no price are skipped; an unknown
	 * buy limit (0) is treated as capital-bound only.
	 */
	public static BudgetPlan plan(List<FlipItem> rankedFlips, long budget)
	{
		List<Allocation> out = new ArrayList<>();
		long remaining = Math.max(0, budget);
		long capitalUsed = 0;
		long totalProfit = 0;
		double gph = 0;
		for (FlipItem f : rankedFlips)
		{
			if (remaining <= 0)
			{
				break;
			}
			// Skip no-margin/no-price AND unknown-limit items: without a buy limit we can
			// neither bound the buy nor estimate a per-hour velocity, so dumping the whole
			// budget into one would be misleading. (Unknown-limit items are rare.)
			if (f.buyPrice <= 0 || f.postTaxMargin <= 0 || f.buyLimit <= 0)
			{
				continue;
			}
			long affordable = remaining / f.buyPrice;
			long qtyL = Math.min((long) f.buyLimit, affordable);
			if (qtyL <= 0)
			{
				continue;
			}
			int qty = (int) Math.min(qtyL, Integer.MAX_VALUE);
			long capital = (long) qty * f.buyPrice;
			long profit = (long) qty * f.postTaxMargin;
			out.add(new Allocation(f, qty, capital, profit));
			remaining -= capital;
			capitalUsed += capital;
			totalProfit += profit;
			// realizedGpPerHour already assumes a FULL buy-limit fill, so scale by the
			// fraction of the limit this allocation actually covers.
			gph += f.realizedGpPerHour * ((double) qty / f.buyLimit);
		}
		return new BudgetPlan(out, budget, capitalUsed, totalProfit, gph);
	}
}
