package com.salehman.ge;

import com.google.inject.Provides;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import javax.inject.Inject;
import javax.swing.SwingUtilities;
import lombok.extern.slf4j.Slf4j;
import net.runelite.client.config.ConfigManager;
import net.runelite.client.eventbus.Subscribe;
import net.runelite.client.events.ConfigChanged;
import net.runelite.client.game.ItemManager;
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

	@Inject
	private ItemManager itemManager;

	@Inject
	private ConfigManager configManager;

	// Shared RuneLite scheduler — used ONLY to FIRE refreshes on the interval; the actual
	// (blocking) network fetch runs on its own short-lived thread so it never stalls the
	// shared executor that other plugins depend on.
	@Inject
	private ScheduledExecutorService executor;

	private NavigationButton navButton;
	// volatile: written on the client thread (startUp/shutDown) and read on the EDT /
	// the refresh worker — publish visibly so a stale/torn reference can't race.
	private volatile SalehmanGePanel panel;
	// autoTask is armed/cancelled from several threads (startUp, shutDown, ConfigChanged) —
	// volatile + all mutation funnelled through synchronized (re)scheduleAuto/cancelAuto.
	private volatile ScheduledFuture<?> autoTask;
	private volatile boolean started;
	// single-flight: drop a refresh if one is already in flight (manual + auto can overlap)…
	private final AtomicBoolean refreshing = new AtomicBoolean(false);
	// …but remember a request that arrived mid-flight (e.g. a sort change) and run it after.
	private final AtomicBoolean pendingRefresh = new AtomicBoolean(false);

	@Provides
	SalehmanGeConfig provideConfig(ConfigManager configManager)
	{
		return configManager.getConfig(SalehmanGeConfig.class);
	}

	@Override
	protected void startUp()
	{
		panel = new SalehmanGePanel(this, itemManager);
		navButton = NavigationButton.builder()
			.tooltip("Salehman GE Flips")
			.icon(buildIcon())
			.priority(7)
			.panel(panel)
			.build();
		clientToolbar.addNavigation(navButton);
		started = true;
		rescheduleAuto();
	}

	@Override
	protected void shutDown()
	{
		started = false;     // block any in-flight reschedule from re-arming after teardown
		cancelAuto();
		final SalehmanGePanel p = panel;
		if (p != null)
		{
			p.stopClock();   // javax.swing.Timer.stop() is thread-safe; prevents a leak per restart
		}
		clientToolbar.removeNavigation(navButton);
		panel = null;
		navButton = null;
	}

	/** Current sort (so the panel's dropdown can initialise to the saved value). */
	public SalehmanGeConfig.SortBy currentSort()
	{
		return config.sortBy();
	}

	/** Panel sort dropdown → persist the choice (config UI stays in sync) and re-rank. */
	public void setSortAndRefresh(SalehmanGeConfig.SortBy sort)
	{
		configManager.setConfiguration("salehmange", "sortBy", sort);
		refresh();
	}

	/** Re-arm (or cancel) the auto-refresh timer to match the current config. */
	private synchronized void rescheduleAuto()
	{
		cancelAutoLocked();
		if (started && config.autoRefresh() && config.refreshSeconds() > 0)
		{
			long s = config.refreshSeconds();
			autoTask = executor.scheduleWithFixedDelay(this::refresh, s, s, TimeUnit.SECONDS);
		}
	}

	private synchronized void cancelAuto()
	{
		cancelAutoLocked();
	}

	private void cancelAutoLocked()
	{
		if (autoTask != null)
		{
			autoTask.cancel(false);
			autoTask = null;
		}
	}

	@Subscribe
	public void onConfigChanged(ConfigChanged e)
	{
		// Only the auto-refresh knobs affect the timer — don't churn it on every sort/filter edit.
		if ("salehmange".equals(e.getGroup())
			&& ("autoRefresh".equals(e.getKey()) || "refreshSeconds".equals(e.getKey())))
		{
			rescheduleAuto();
		}
	}

	/**
	 * Fetch + rank off the EDT (network), then push results back on the EDT. Triggered by
	 * the panel's refresh button and the auto-refresh timer. Single-flight: a refresh that
	 * arrives while one is already running is dropped rather than piling up.
	 */
	public void refresh()
	{
		final SalehmanGePanel p = panel;
		if (p == null)
		{
			return;
		}
		if (!refreshing.compareAndSet(false, true))
		{
			// A refresh is already running (e.g. an auto tick); remember this request and
			// run it once that finishes, so a sort change is never silently dropped.
			pendingRefresh.set(true);
			return;
		}
		// setLoading touches Swing — auto-refresh fires off the EDT, so marshal it on.
		SwingUtilities.invokeLater(() -> { if (p == panel) p.setLoading(true); });
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
			finally
			{
				refreshing.set(false);
				if (pendingRefresh.compareAndSet(true, false))
				{
					refresh();   // honour a request that arrived while this one was in flight
				}
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
