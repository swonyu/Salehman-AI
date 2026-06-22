package com.salehman.ge;

import com.google.inject.Provides;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.util.List;
import javax.inject.Inject;
import javax.swing.SwingUtilities;
import lombok.extern.slf4j.Slf4j;
import net.runelite.client.config.ConfigManager;
import net.runelite.client.plugins.Plugin;
import net.runelite.client.plugins.PluginDescriptor;
import net.runelite.client.ui.ClientToolbar;
import net.runelite.client.ui.NavigationButton;

/**
 * Salehman GE Flips — a side panel that ranks live Grand Exchange flip
 * opportunities (post-tax margin / ROI / profit-per-limit) from the community
 * prices.runescape.wiki feed. The RuneLite extension version of Salehman AI's
 * Old School RuneScape Grand Exchange feature.
 */
@Slf4j
@PluginDescriptor(
	name = "Salehman GE Flips",
	description = "Live Grand Exchange flip finder: post-tax margins, ROI and profit-per-limit from real-time wiki prices.",
	tags = {"grand", "exchange", "ge", "flip", "money", "merch", "price", "osrs"}
)
public class SalehmanGePlugin extends Plugin
{
	@Inject
	private ClientToolbar clientToolbar;

	@Inject
	private FlipFinder flipFinder;

	@Inject
	private SalehmanGeConfig config;

	private NavigationButton navButton;
	// volatile: written on the client thread (startUp/shutDown) and read on the EDT /
	// the refresh worker — publish visibly so a stale/torn reference can't race.
	private volatile SalehmanGePanel panel;

	@Provides
	SalehmanGeConfig provideConfig(ConfigManager configManager)
	{
		return configManager.getConfig(SalehmanGeConfig.class);
	}

	@Override
	protected void startUp()
	{
		panel = new SalehmanGePanel(this);
		navButton = NavigationButton.builder()
			.tooltip("Salehman GE Flips")
			.icon(buildIcon())
			.priority(7)
			.panel(panel)
			.build();
		clientToolbar.addNavigation(navButton);
	}

	@Override
	protected void shutDown()
	{
		clientToolbar.removeNavigation(navButton);
		panel = null;
		navButton = null;
	}

	/**
	 * Fetch + rank off the EDT (network), then push results back on the EDT.
	 * Triggered by the panel's refresh button.
	 */
	public void refresh()
	{
		final SalehmanGePanel p = panel;
		if (p == null)
		{
			return;
		}
		p.setLoading(true);
		new Thread(() ->
		{
			try
			{
				List<FlipItem> flips = flipFinder.findFlips(config);
				// `p == panel` guards a late result landing after shutDown() (panel→null)
				// or a panel swap — don't mutate a detached panel. (panel is volatile.)
				SwingUtilities.invokeLater(() -> { if (p == panel) p.setFlips(flips); });
			}
			catch (Exception ex)
			{
				log.warn("GE flip refresh failed", ex);
				SwingUtilities.invokeLater(() -> { if (p == panel) p.showError("Couldn't reach the price feed — try again."); });
			}
		}, "salehman-ge-refresh").start();
	}

	/** Generate the toolbar icon in code so no binary resource is needed. */
	private static BufferedImage buildIcon()
	{
		BufferedImage img = new BufferedImage(24, 24, BufferedImage.TYPE_INT_ARGB);
		Graphics2D g = img.createGraphics();
		g.setColor(new Color(0xE0, 0x2B, 0x20));
		g.fillRoundRect(2, 2, 20, 20, 7, 7);
		g.setColor(Color.WHITE);
		g.setFont(g.getFont().deriveFont(14f).deriveFont(java.awt.Font.BOLD));
		g.drawString("G", 7, 18);
		g.dispose();
		return img;
	}
}
