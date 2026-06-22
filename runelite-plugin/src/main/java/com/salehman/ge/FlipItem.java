package com.salehman.ge;

/**
 * One ranked Grand Exchange flip: buy near the instant-sell price, sell near the
 * instant-buy price, pocket the post-tax margin (capped by the 4h buy limit).
 * Immutable value object.
 */
public class FlipItem
{
	public final int id;
	public final String name;
	public final int buyPrice;        // ~instant-sell (low) — where you place the buy offer
	public final int sellPrice;       // ~instant-buy (high) — where you place the sell offer
	public final int margin;          // sellPrice - buyPrice (gross)
	public final int tax;             // GE tax on the sale
	public final int postTaxMargin;   // margin - tax (per item)
	public final double roi;          // postTaxMargin / buyPrice, percent
	public final int buyLimit;        // 4h GE buy limit (0 = unknown)
	public final long dailyVolume;
	public final long potentialProfit; // postTaxMargin * buyLimit
	// MONEY VELOCITY: gp PER HOUR = potentialProfit / 4h buy-limit window — mirrors the
	// macOS app's StockSageGEFlip.gpPerHour so a fast-turnover item beats a fat-margin
	// one you can barely buy. An estimate that assumes you fill the limit each window.
	public final double gpPerHour;
	public final boolean members;
	/// Age of the OLDEST (stalest) of the two quote legs, in seconds (-1 if unknown) —
	/// the limiting factor for a two-sided flip, so a half-stale spread is judged correctly.
	public final long ageSeconds;

	public FlipItem(int id, String name, int buyPrice, int sellPrice, int margin, int tax,
		int postTaxMargin, double roi, int buyLimit, long dailyVolume, long potentialProfit,
		double gpPerHour, boolean members, long ageSeconds)
	{
		this.id = id;
		this.name = name;
		this.buyPrice = buyPrice;
		this.sellPrice = sellPrice;
		this.margin = margin;
		this.tax = tax;
		this.postTaxMargin = postTaxMargin;
		this.roi = roi;
		this.buyLimit = buyLimit;
		this.dailyVolume = dailyVolume;
		this.potentialProfit = potentialProfit;
		this.gpPerHour = gpPerHour;
		this.members = members;
		this.ageSeconds = ageSeconds;
	}
}
