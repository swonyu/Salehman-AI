package com.salehman.ge;

import net.runelite.client.config.Config;
import net.runelite.client.config.ConfigGroup;
import net.runelite.client.config.ConfigItem;

/** User-tunable filters + sort for the flip finder. */
@ConfigGroup("salehmange")
public interface SalehmanGeConfig extends Config
{
	enum SortBy
	{
		POTENTIAL_PROFIT,
		ROI,
		MARGIN
	}

	@ConfigItem(
		keyName = "minMargin",
		name = "Min post-tax margin",
		description = "Hide flips whose per-item profit (after GE tax) is below this.",
		position = 1
	)
	default int minMargin()
	{
		return 50;
	}

	@ConfigItem(
		keyName = "minVolume",
		name = "Min daily volume",
		description = "Hide thinly-traded items (sum of daily insta-buy + insta-sell volume).",
		position = 2
	)
	default int minVolume()
	{
		return 1000;
	}

	@ConfigItem(
		keyName = "minPrice",
		name = "Min price",
		description = "Ignore items cheaper than this (buy price).",
		position = 3
	)
	default int minPrice()
	{
		return 0;
	}

	@ConfigItem(
		keyName = "maxPrice",
		name = "Max price (0 = no cap)",
		description = "Ignore items dearer than this (sell price). 0 disables the cap.",
		position = 4
	)
	default int maxPrice()
	{
		return 0;
	}

	@ConfigItem(
		keyName = "membersOnly",
		name = "Members items only",
		description = "Restrict to members-only items.",
		position = 5
	)
	default boolean membersOnly()
	{
		return false;
	}

	@ConfigItem(
		keyName = "maxResults",
		name = "Max results",
		description = "How many ranked flips to show.",
		position = 6
	)
	default int maxResults()
	{
		return 30;
	}

	@ConfigItem(
		keyName = "sortBy",
		name = "Sort by",
		description = "Rank flips by total potential profit, ROI %, or per-item margin.",
		position = 7
	)
	default SortBy sortBy()
	{
		return SortBy.POTENTIAL_PROFIT;
	}

	@ConfigItem(
		keyName = "taxPercent",
		name = "GE tax %",
		description = "Grand Exchange sell tax percentage (OSRS default 1%). Verify against current game rules.",
		position = 8
	)
	default int taxPercent()
	{
		return 1;
	}

	@ConfigItem(
		keyName = "taxCap",
		name = "GE tax cap (gp)",
		description = "Maximum GE tax per item (OSRS default 5,000,000).",
		position = 9
	)
	default int taxCap()
	{
		return 5_000_000;
	}

	@ConfigItem(
		keyName = "maxStaleMinutes",
		name = "Max quote age (min, 0 = off)",
		description = "Skip flips whose newest instant-buy/sell trade is older than this — a wide spread on stale prices isn't really tradeable. 0 disables the filter.",
		position = 10
	)
	default int maxStaleMinutes()
	{
		return 60;
	}
}
