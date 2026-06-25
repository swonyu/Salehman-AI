package com.salehman.ge;

import net.runelite.client.config.Config;
import net.runelite.client.config.ConfigGroup;
import net.runelite.client.config.ConfigItem;
import net.runelite.client.config.ConfigSection;
import net.runelite.client.config.Range;
import net.runelite.client.config.Units;

/** User-tunable filters, ranking, tax model and auto-refresh for the flip finder. */
@ConfigGroup("salehmange")
public interface SalehmanGeConfig extends Config
{
	enum SortBy
	{
		POTENTIAL_PROFIT,
		ROI,
		MARGIN,
		VELOCITY,           // gp/hour (theoretical) — fastest-compounding flips
		REALIZED_VELOCITY   // gp/hour × freshness confidence — down-ranks stale quotes
	}

	@ConfigSection(name = "Filters", description = "Which flips to show", position = 0)
	String filtersSection = "filters";

	@ConfigSection(name = "Ranking & display", description = "How flips are ranked and how many", position = 1)
	String rankingSection = "ranking";

	@ConfigSection(name = "Auto-refresh", description = "Automatically re-fetch prices", position = 2)
	String refreshSection = "refresh";

	@ConfigSection(name = "GE tax", description = "Sell-tax model used for net margins", position = 3)
	String taxSection = "tax";

	@ConfigSection(name = "Notifications", description = "Alert when a great flip appears", position = 4)
	String notificationsSection = "notifications";

	@ConfigSection(name = "Budget plan", description = "The 'I have N gp' allocator", position = 5)
	String budgetSection = "budget";

	@ConfigSection(name = "In-game overlay", description = "On-screen top-flips HUD", position = 6)
	String overlaySection = "overlay";

	@ConfigItem(
		keyName = "minMargin",
		name = "Min post-tax margin",
		description = "Hide flips whose per-item profit (after GE tax) is below this.",
		position = 1,
		section = filtersSection
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
		position = 2,
		section = filtersSection
	)
	default int minVolume()
	{
		return 1000;
	}

	@ConfigItem(
		keyName = "minPrice",
		name = "Min price",
		description = "Ignore items cheaper than this (buy price).",
		position = 3,
		section = filtersSection
	)
	default int minPrice()
	{
		return 0;
	}

	@ConfigItem(
		keyName = "maxPrice",
		name = "Max price (0 = no cap)",
		description = "Ignore items dearer than this (sell price). 0 disables the cap.",
		position = 4,
		section = filtersSection
	)
	default int maxPrice()
	{
		return 0;
	}

	@ConfigItem(
		keyName = "membersOnly",
		name = "Members items only",
		description = "Restrict to members-only items.",
		position = 5,
		section = filtersSection
	)
	default boolean membersOnly()
	{
		return false;
	}

	@ConfigItem(
		keyName = "maxStaleMinutes",
		name = "Max quote age (min, 0 = off)",
		description = "Skip flips whose OLDER instant-buy/sell leg is older than this — a wide spread on stale prices isn't really tradeable. 0 disables the filter.",
		position = 6,
		section = filtersSection
	)
	@Units(Units.MINUTES)
	default int maxStaleMinutes()
	{
		return 60;
	}

	@ConfigItem(
		keyName = "maxResults",
		name = "Max results",
		description = "How many ranked flips to display (the budget plan still spans every flip).",
		position = 1,
		section = rankingSection
	)
	default int maxResults()
	{
		return 30;
	}

	@ConfigItem(
		keyName = "sortBy",
		name = "Sort by",
		description = "Rank by potential profit, ROI %, per-item margin, velocity (gp/hour), or "
			+ "realized velocity (gp/hour discounted by quote freshness — the default).",
		position = 2,
		section = rankingSection
	)
	default SortBy sortBy()
	{
		return SortBy.REALIZED_VELOCITY;
	}

	@ConfigItem(
		keyName = "autoRefresh",
		name = "Auto-refresh",
		description = "Re-fetch live prices automatically on an interval.",
		position = 1,
		section = refreshSection
	)
	default boolean autoRefresh()
	{
		return false;
	}

	@ConfigItem(
		keyName = "refreshSeconds",
		name = "Refresh interval",
		description = "Seconds between auto-refreshes (when Auto-refresh is on).",
		position = 2,
		section = refreshSection
	)
	@Range(min = 10, max = 600)
	@Units(Units.SECONDS)
	default int refreshSeconds()
	{
		return 60;
	}

	@ConfigItem(
		keyName = "taxPercent",
		name = "GE tax",
		description = "Grand Exchange sell tax percentage (OSRS is 2% since 2025-05-29). Verify against current game rules.",
		position = 1,
		section = taxSection
	)
	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	default int taxPercent()
	{
		return 2;
	}

	@ConfigItem(
		keyName = "taxCap",
		name = "GE tax cap (gp)",
		description = "Maximum GE tax per item (OSRS default 5,000,000).",
		position = 2,
		section = taxSection
	)
	@Range(min = 0, max = 5_000_000)
	default int taxCap()
	{
		return 5_000_000;
	}

	@ConfigItem(
		keyName = "notifyEnabled",
		name = "Notify on great flips",
		description = "Send a notification when a refresh finds a flip above the gp/hour threshold (best with auto-refresh).",
		position = 1,
		section = notificationsSection
	)
	default boolean notifyEnabled()
	{
		return false;
	}

	@ConfigItem(
		keyName = "notifyMinGpPerHour",
		name = "Notify threshold (gp/hour)",
		description = "Only notify for flips whose realized gp/hour is at least this.",
		position = 2,
		section = notificationsSection
	)
	default int notifyMinGpPerHour()
	{
		return 1_000_000;
	}

	@ConfigItem(
		keyName = "maxAllocationPct",
		name = "Max % of budget per item",
		description = "Diversification cap: limit how much of your budget the plan puts into any single flip "
			+ "(spills to the next). 0 = no cap. Lower = safer against a single item not filling.",
		position = 1,
		section = budgetSection
	)
	@Range(min = 0, max = 100)
	@Units(Units.PERCENT)
	default int maxAllocationPct()
	{
		return 0;
	}

	@ConfigItem(
		keyName = "overlayEnabled",
		name = "Show in-game overlay",
		description = "Draw a small on-screen HUD listing your top flips (draggable). Off by default.",
		position = 1,
		section = overlaySection
	)
	default boolean overlayEnabled()
	{
		return false;
	}

	@ConfigItem(
		keyName = "overlayCount",
		name = "Overlay rows",
		description = "How many top flips to list in the in-game overlay.",
		position = 2,
		section = overlaySection
	)
	@Range(min = 1, max = 15)
	default int overlayCount()
	{
		return 5;
	}
}
