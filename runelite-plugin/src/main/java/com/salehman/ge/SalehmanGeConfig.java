package com.salehman.ge;

import net.runelite.client.config.Config;
import net.runelite.client.config.ConfigGroup;
import net.runelite.client.config.ConfigItem;
import net.runelite.client.config.Range;

/** User-tunable filters + sort for the flip finder. */
@ConfigGroup("salehmange")
public interface SalehmanGeConfig extends Config
{
	enum SortBy
	{
		POTENTIAL_PROFIT,
		ROI,
		MARGIN,
		VELOCITY        // gp/hour — fastest-compounding flips (money velocity)
	}

	@ConfigItem(
		keyName = "minMargin",
		name = "Min post-tax margin",
		description = "Hide flips whose per-item profit (after GE tax) is below this.",
		position = 1
	)
	@Range(min = 0, max = 2_000_000_000)
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
		description = "Rank flips by total potential profit, ROI %, per-item margin, or velocity (gp/hour).",
		position = 7
	)
	default SortBy sortBy()
	{
		return SortBy.POTENTIAL_PROFIT;
	}

	@ConfigItem(
		keyName = "taxPercent",
		name = "GE tax %",
		description = "Grand Exchange sell tax percentage (OSRS is 2% since 2025-05-29). Verify against current game rules.",
		position = 8
	)
	@Range(min = 0, max = 100)
	default int taxPercent()
	{
		return 2;
	}

	@ConfigItem(
		keyName = "taxCap",
		name = "GE tax cap (gp)",
		description = "Maximum GE tax per item (OSRS default 5,000,000).",
		position = 9
	)
	@Range(min = 0, max = 5_000_000)
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
