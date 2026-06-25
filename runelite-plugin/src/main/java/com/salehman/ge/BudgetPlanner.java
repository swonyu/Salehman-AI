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
		// Herfindahl concentration of capital across items: 1.0 = all in one flip, →0 = spread.
		public final double concentrationRisk;

		BudgetPlan(List<Allocation> allocations, long budget, long capitalUsed,
			long totalProfit, double realizedGpPerHour, double concentrationRisk)
		{
			this.allocations = allocations;
			this.budget = budget;
			this.capitalUsed = capitalUsed;
			this.totalProfit = totalProfit;
			this.realizedGpPerHour = realizedGpPerHour;
			this.concentrationRisk = concentrationRisk;
		}
	}

	/** Convenience: allocate with no per-item diversification cap. */
	public static BudgetPlan plan(List<FlipItem> rankedFlips, long budget)
	{
		return plan(rankedFlips, budget, 0);
	}

	/**
	 * Allocate {@code budget} gp across {@code rankedFlips} in their given order, buying up
	 * to each item's buy limit. Items with no margin/price or an unknown buy limit are
	 * skipped. {@code maxCapitalPerItem} (gp; ≤0 = no cap) caps how much capital any single
	 * flip may absorb, spilling the rest to the next flip — diversification / fill-risk control.
	 */
	public static BudgetPlan plan(List<FlipItem> rankedFlips, long budget, long maxCapitalPerItem)
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
			if (f.buyPrice <= 0 || f.postTaxMargin <= 0 || f.buyLimit <= 0)
			{
				continue;
			}
			long spendCap = remaining;
			if (maxCapitalPerItem > 0)
			{
				spendCap = Math.min(spendCap, maxCapitalPerItem);   // diversification cap
			}
			long affordable = spendCap / f.buyPrice;
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
		double concentration = 0;
		if (capitalUsed > 0)
		{
			for (Allocation a : out)
			{
				double share = (double) a.capital / capitalUsed;
				concentration += share * share;
			}
		}
		return new BudgetPlan(out, budget, capitalUsed, totalProfit, gph, concentration);
	}
}
