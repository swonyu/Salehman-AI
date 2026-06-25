package com.salehman.ge;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.Graphics2D;
import java.util.List;
import net.runelite.client.ui.overlay.OverlayPanel;
import net.runelite.client.ui.overlay.OverlayPosition;
import net.runelite.client.ui.overlay.components.LineComponent;
import net.runelite.client.ui.overlay.components.TitleComponent;
import net.runelite.client.util.QuantityFormatter;

/**
 * Opt-in on-screen HUD listing the top flips (draggable like any RuneLite overlay).
 * Deliberately NOT coupled to the Grand Exchange game widget (those ids vary): it simply
 * shows the latest ranked flips when enabled, and nothing until a refresh has produced data.
 */
class SalehmanGeOverlay extends OverlayPanel
{
	private static final Color GREEN = new Color(0x5F, 0xD6, 0x6B);

	private final SalehmanGePlugin plugin;
	private final SalehmanGeConfig config;

	SalehmanGeOverlay(SalehmanGePlugin plugin, SalehmanGeConfig config)
	{
		super(plugin);
		this.plugin = plugin;
		this.config = config;
		setPosition(OverlayPosition.TOP_LEFT);
	}

	@Override
	public Dimension render(Graphics2D graphics)
	{
		if (!config.overlayEnabled())
		{
			return null;
		}
		List<FlipItem> all = plugin.latestFlips();
		if (all.isEmpty())
		{
			return null;
		}
		// The panel may be sorted by any metric; the overlay always shows gp/hour, so order
		// its own copy by realized gp/hour to match the figure displayed.
		List<FlipItem> flips = new java.util.ArrayList<>(all);
		flips.sort(java.util.Comparator.comparingDouble((FlipItem f) -> f.realizedGpPerHour).reversed());
		panelComponent.getChildren().clear();
		panelComponent.getChildren().add(TitleComponent.builder().text("GE Flips").color(Color.WHITE).build());
		int n = Math.min(flips.size(), Math.max(1, config.overlayCount()));
		for (int i = 0; i < n; i++)
		{
			FlipItem f = flips.get(i);
			panelComponent.getChildren().add(LineComponent.builder()
				.left(f.name)
				.right(QuantityFormatter.quantityToStackSize((long) f.realizedGpPerHour) + "/h")
				.rightColor(GREEN)
				.build());
		}
		panelComponent.setPreferredSize(new Dimension(170, 0));
		return super.render(graphics);
	}
}
