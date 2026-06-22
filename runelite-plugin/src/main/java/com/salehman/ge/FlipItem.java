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
	public final boolean members;
	/// Age of the freshest of the two quotes, in seconds (-1 if unknown).
	public final long ageSeconds;

	public FlipItem(int id, String name, int buyPrice, int sellPrice, int margin, int tax,
		int postTaxMargin, double roi, int buyLimit, long dailyVolume, long potentialProfit,
		boolean members, long ageSeconds)
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
		this.members = members;
		this.ageSeconds = ageSeconds;
	}
}
