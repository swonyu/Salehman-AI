package com.salehman.ge;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.Container;
import java.awt.Cursor;
import java.awt.Dimension;
import java.awt.GridLayout;
import java.awt.Toolkit;
import java.awt.datatransfer.StringSelection;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.text.NumberFormat;
import java.util.List;
import java.util.Locale;
import javax.swing.BorderFactory;
import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.DefaultListCellRenderer;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JList;
import javax.swing.JMenuItem;
import javax.swing.JPanel;
import javax.swing.JPopupMenu;
import javax.swing.SwingConstants;
import javax.swing.Timer;
import net.runelite.client.game.ItemManager;
import net.runelite.client.ui.ColorScheme;
import net.runelite.client.ui.FontManager;
import net.runelite.client.ui.PluginPanel;
import net.runelite.client.util.LinkBrowser;
import net.runelite.client.util.QuantityFormatter;

/**
 * The side panel: a sort selector + refresh, a live "updated Ns ago" clock, ranked
 * flip rows (item icon, hero profit, freshness dot, compact stats; click → wiki price
 * page, right-click → menu), and an honest disclaimer.
 */
class SalehmanGePanel extends PluginPanel
{
	private static final NumberFormat GP = NumberFormat.getIntegerInstance(Locale.US);
	private static final Color ALCH_COLOR = new Color(0x4F, 0xC3, 0xF7); // cyan — distinct from profit-green
	private static final Color CHART_COLOR = new Color(0x7F, 0xB3, 0xFF); // sparkline line
	private static final int VOLUME_GATE_FACTOR = 3; // daily volume below limit×this → "thin volume"

	private final SalehmanGePlugin plugin;
	private final ItemManager itemManager;
	private final JPanel list = new JPanel();
	private final JLabel status = new JLabel("Tap Refresh to find flips.");
	private final JLabel updated = new JLabel(" ");
	private final JButton refresh = new JButton("Refresh");
	private final javax.swing.JTextField budgetField = new javax.swing.JTextField();
	private final javax.swing.JTextField searchField = new javax.swing.JTextField();
	private final Timer clock = new Timer(1000, e -> tickUpdated());

	private final javax.swing.JCheckBox favOnly = new javax.swing.JCheckBox("★ favourites only");

	private long lastUpdatedMs = -1;
	private long budget = 0;
	private String nameFilter = "";
	private java.util.List<FlipItem> lastFlips = java.util.Collections.emptyList();
	// price-history sparkline: which rows are expanded, the fetched mids (empty = no data), in-flight
	private final java.util.Set<Integer> expanded = new java.util.HashSet<>();
	private final java.util.Map<Integer, int[]> sparkCache = new java.util.HashMap<>();
	private final java.util.Set<Integer> sparkLoading = new java.util.HashSet<>();
	private boolean disposed = false;   // set on teardown; late async callbacks then no-op

	SalehmanGePanel(SalehmanGePlugin plugin, ItemManager itemManager)
	{
		this.plugin = plugin;
		this.itemManager = itemManager;
		setLayout(new BorderLayout(0, 8));
		setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));

		add(buildHeader(), BorderLayout.NORTH);

		list.setLayout(new BoxLayout(list, BoxLayout.Y_AXIS));
		list.setBackground(ColorScheme.DARK_GRAY_COLOR);
		add(list, BorderLayout.CENTER);

		JLabel disclaimer = new JLabel("<html>Community ~real-time prices, not official. "
			+ "Flipping isn't risk-free — offers may not fill and prices move. Informational only.</html>");
		disclaimer.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		disclaimer.setFont(FontManager.getRunescapeSmallFont());
		add(disclaimer, BorderLayout.SOUTH);

		// Live "updated Ns ago" tick (1s, EDT). A fresh panel is created on every plugin
		// startUp, so the plugin stops this clock in shutDown() to avoid leaking a Timer
		// (and a panel reference) per enable/disable cycle.
		clock.start();
	}

	/** Teardown: stop the clock (no Timer leak) and mark disposed so late async callbacks no-op. */
	void stopClock()
	{
		disposed = true;
		clock.stop();
	}

	private JPanel buildHeader()
	{
		JPanel header = new JPanel(new BorderLayout(0, 6));
		header.setBackground(ColorScheme.DARK_GRAY_COLOR);

		JLabel title = new JLabel("Grand Exchange Flips");
		title.setFont(FontManager.getRunescapeBoldFont());
		title.setForeground(Color.WHITE);
		header.add(title, BorderLayout.NORTH);

		// Controls: sort selector + refresh, each full width.
		JPanel controls = new JPanel(new GridLayout(0, 1, 0, 4));
		controls.setBackground(ColorScheme.DARK_GRAY_COLOR);

		JComboBox<SalehmanGeConfig.SortBy> sortBox = new JComboBox<>(SalehmanGeConfig.SortBy.values());
		sortBox.setSelectedItem(plugin.currentSort());     // set BEFORE adding the listener (no spurious refresh)
		sortBox.setRenderer(new DefaultListCellRenderer()
		{
			@Override
			public Component getListCellRendererComponent(JList<?> l, Object v, int i, boolean sel, boolean foc)
			{
				super.getListCellRendererComponent(l, v, i, sel, foc);
				if (v instanceof SalehmanGeConfig.SortBy)
				{
					setText(sortLabel((SalehmanGeConfig.SortBy) v));
				}
				return this;
			}
		});
		sortBox.addActionListener(e ->
		{
			Object s = sortBox.getSelectedItem();
			if (s instanceof SalehmanGeConfig.SortBy)
			{
				plugin.setSortAndRefresh((SalehmanGeConfig.SortBy) s);
			}
		});
		controls.add(sortBox);

		// Live name filter over the displayed rows (does not refetch or re-rank).
		searchField.setToolTipText("Filter by item name");
		searchField.getDocument().addDocumentListener(new javax.swing.event.DocumentListener()
		{
			@Override
			public void insertUpdate(javax.swing.event.DocumentEvent e)
			{
				onSearch();
			}

			@Override
			public void removeUpdate(javax.swing.event.DocumentEvent e)
			{
				onSearch();
			}

			@Override
			public void changedUpdate(javax.swing.event.DocumentEvent e)
			{
				onSearch();
			}
		});
		controls.add(searchField);

		// Budget: "I have N gp" → an allocation plan (accepts 100m / 1.5b / 250000).
		JPanel budgetRow = new JPanel(new BorderLayout(6, 0));
		budgetRow.setBackground(ColorScheme.DARK_GRAY_COLOR);
		JLabel budgetLabel = new JLabel("Budget");
		budgetLabel.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		budgetLabel.setFont(FontManager.getRunescapeSmallFont());
		budgetField.setToolTipText("Your gp to spend (e.g. 100m). Blank = no plan.");
		budgetField.addActionListener(e -> applyBudget());     // Enter
		budgetField.addFocusListener(new java.awt.event.FocusAdapter()
		{
			@Override
			public void focusLost(java.awt.event.FocusEvent e)
			{
				applyBudget();
			}
		});
		budgetRow.add(budgetLabel, BorderLayout.WEST);
		budgetRow.add(budgetField, BorderLayout.CENTER);
		controls.add(budgetRow);

		favOnly.setBackground(ColorScheme.DARK_GRAY_COLOR);
		favOnly.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		favOnly.setFont(FontManager.getRunescapeSmallFont());
		favOnly.setFocusable(false);
		favOnly.addActionListener(e -> renderList());
		controls.add(favOnly);

		refresh.setFocusable(false);
		refresh.addActionListener(e -> plugin.refresh());
		controls.add(refresh);
		header.add(controls, BorderLayout.CENTER);

		JPanel statusPanel = new JPanel(new GridLayout(0, 1));
		statusPanel.setBackground(ColorScheme.DARK_GRAY_COLOR);
		status.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		status.setFont(FontManager.getRunescapeSmallFont());
		updated.setForeground(ColorScheme.MEDIUM_GRAY_COLOR);
		updated.setFont(FontManager.getRunescapeSmallFont());
		statusPanel.add(status);
		statusPanel.add(updated);
		header.add(statusPanel, BorderLayout.SOUTH);

		return header;
	}

	void setLoading(boolean loading)
	{
		refresh.setEnabled(!loading);
		refresh.setText(loading ? "Loading…" : "Refresh");
		if (loading)
		{
			status.setText("Fetching live prices…");
		}
	}

	void showError(String message)
	{
		setLoading(false);
		status.setForeground(ColorScheme.PROGRESS_ERROR_COLOR);
		status.setText(message);
	}

	void setFlips(List<FlipItem> flips)
	{
		setLoading(false);
		status.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		lastFlips = flips;
		if (flips.isEmpty())
		{
			status.setText("No flips match your filters.");
		}
		else
		{
			int cap = plugin.maxResults();
			status.setText(flips.size() <= cap
				? flips.size() + " flips · ranked"
				: "top " + cap + " of " + flips.size() + " · ranked");
			lastUpdatedMs = System.currentTimeMillis();
		}
		renderList();
		tickUpdated();
	}

	private void applyBudget()
	{
		long b = parseGp(budgetField.getText());
		if (b != budget)
		{
			budget = b;
			renderList();   // re-render with/without the allocation plan (no network needed)
		}
	}

	/** Rebuild the rows from {@link #lastFlips}, prepending a budget plan when one is set. */
	private void renderList()
	{
		list.removeAll();
		if (!lastFlips.isEmpty())
		{
			java.util.Map<Integer, Integer> alloc = java.util.Collections.emptyMap();
			if (budget > 0)
			{
				int pct = plugin.maxAllocationPct();
				long capPerItem = pct > 0 ? (long) (budget * (pct / 100.0)) : 0;
				BudgetPlanner.BudgetPlan plan = BudgetPlanner.plan(lastFlips, budget, capPerItem);
				list.add(planSummary(plan));
				list.add(Box.createVerticalStrut(6));
				alloc = new java.util.HashMap<>();
				for (BudgetPlanner.Allocation a : plan.allocations)
				{
					alloc.put(a.flip.id, a.quantity);
				}
			}
			// favourites pinned to the top, keeping their relative ranked order
			java.util.List<FlipItem> display = new java.util.ArrayList<>();
			for (FlipItem f : lastFlips)
			{
				if (plugin.isFavorite(f.id))
				{
					display.add(f);
				}
			}
			for (FlipItem f : lastFlips)
			{
				if (!plugin.isFavorite(f.id))
				{
					display.add(f);
				}
			}
			boolean favoritesOnly = favOnly.isSelected();
			int cap = plugin.maxResults();   // display cap; the budget plan above spans ALL flips
			int shown = 0;
			for (FlipItem f : display)
			{
				if (shown >= cap)
				{
					break;
				}
				if (favoritesOnly && !plugin.isFavorite(f.id))
				{
					continue;
				}
				if (!nameFilter.isEmpty() && !f.name.toLowerCase(Locale.US).contains(nameFilter))
				{
					continue;   // filters/cap only hide rows; the budget plan still spans all flips
				}
				list.add(row(f, alloc.getOrDefault(f.id, 0)));
				list.add(Box.createVerticalStrut(6));
				shown++;
			}
		}
		list.revalidate();
		list.repaint();
	}

	private void onSearch()
	{
		nameFilter = searchField.getText().trim().toLowerCase(Locale.US);
		renderList();
	}

	private JPanel planSummary(BudgetPlanner.BudgetPlan plan)
	{
		JPanel p = new JPanel();
		p.setLayout(new BoxLayout(p, BoxLayout.Y_AXIS));
		p.setBackground(ColorScheme.DARKER_GRAY_COLOR);
		p.setBorder(BorderFactory.createCompoundBorder(
			BorderFactory.createMatteBorder(0, 3, 0, 0, ColorScheme.BRAND_ORANGE),
			BorderFactory.createEmptyBorder(6, 8, 6, 8)));
		JLabel head = new JLabel("Plan for " + QuantityFormatter.quantityToStackSize(plan.budget) + " gp");
		head.setForeground(Color.WHITE);
		head.setFont(FontManager.getRunescapeBoldFont());
		head.setAlignmentX(LEFT_ALIGNMENT);
		p.add(head);
		JLabel profit = new JLabel("+" + QuantityFormatter.quantityToStackSize(plan.totalProfit)
			+ " profit  ·  " + QuantityFormatter.quantityToStackSize((long) plan.realizedGpPerHour) + "/h");
		profit.setForeground(ColorScheme.PROGRESS_COMPLETE_COLOR);
		profit.setFont(FontManager.getRunescapeBoldFont());
		profit.setAlignmentX(LEFT_ALIGNMENT);
		p.add(profit);
		// Extrapolation: one buy-limit fill is a 4h cycle; ~6 cycles/day if you re-fill each reset.
		p.add(dim("≈ +" + QuantityFormatter.quantityToStackSize(plan.totalProfit * 6) + "/day if refilled each reset"));
		JComponent spend = kv("Spend", QuantityFormatter.quantityToStackSize(plan.capitalUsed)
			+ " · " + plan.allocations.size() + " items", Color.WHITE);
		spend.setAlignmentX(LEFT_ALIGNMENT);
		p.add(spend);
		// Concentration: 1.0 = all-in-one (risky), lower = spread. Flag when capital is concentrated.
		if (plan.allocations.size() > 1)
		{
			p.add(dim(String.format(Locale.US, "concentration %.2f%s", plan.concentrationRisk,
				plan.concentrationRisk >= 0.5 ? " (heavy)" : "")));
		}
		if (favOnly.isSelected() || !nameFilter.isEmpty())
		{
			JLabel note = new JLabel("plan spans all flips; some rows hidden by filter");
			note.setForeground(ColorScheme.MEDIUM_GRAY_COLOR);
			note.setFont(FontManager.getRunescapeSmallFont());
			note.setAlignmentX(LEFT_ALIGNMENT);
			p.add(note);
		}
		return p;
	}

	private static long parseGp(String s)
	{
		if (s == null)
		{
			return 0;
		}
		s = s.trim().toLowerCase(Locale.US).replace(",", "").replace("gp", "").trim();
		if (s.isEmpty())
		{
			return 0;
		}
		double mult = 1;
		char last = s.charAt(s.length() - 1);
		if (last == 'k')
		{
			mult = 1e3;
			s = s.substring(0, s.length() - 1);
		}
		else if (last == 'm')
		{
			mult = 1e6;
			s = s.substring(0, s.length() - 1);
		}
		else if (last == 'b')
		{
			mult = 1e9;
			s = s.substring(0, s.length() - 1);
		}
		try
		{
			return (long) (Double.parseDouble(s.trim()) * mult);
		}
		catch (NumberFormatException e)
		{
			return 0;
		}
	}

	private void tickUpdated()
	{
		if (lastUpdatedMs < 0)
		{
			updated.setText(" ");
			return;
		}
		long s = (System.currentTimeMillis() - lastUpdatedMs) / 1000;
		updated.setText("Updated " + (s < 60 ? s + "s" : (s / 60) + "m") + " ago");
	}

	private JPanel row(FlipItem f, int allocQty)
	{
		// BoxLayout stretches/squashes children to their max size, so cap only the WIDTH and
		// let height follow the content (a fixed height cap crushed the rows and overprinted).
		JPanel row = new JPanel(new BorderLayout(8, 0))
		{
			@Override
			public Dimension getMaximumSize()
			{
				return new Dimension(Integer.MAX_VALUE, getPreferredSize().height);
			}
		};
		row.setBackground(ColorScheme.DARKER_GRAY_COLOR);
		row.setBorder(BorderFactory.createEmptyBorder(6, 8, 6, 8));
		row.setAlignmentX(LEFT_ALIGNMENT);
		row.setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));

		// Item icon (async: paints itself when the sprite loads off RuneLite's item cache).
		JLabel icon = new JLabel();
		icon.setPreferredSize(new Dimension(36, 36));
		icon.setVerticalAlignment(SwingConstants.TOP);
		icon.setHorizontalAlignment(SwingConstants.CENTER);
		itemManager.getImage(f.id).addTo(icon);
		row.add(icon, BorderLayout.WEST);

		JPanel body = new JPanel();
		body.setLayout(new BoxLayout(body, BoxLayout.Y_AXIS));
		body.setOpaque(false);
		row.add(body, BorderLayout.CENTER);

		// name + freshness dot
		JPanel nameLine = fullWidth(new BorderLayout(4, 0));
		JLabel name = new JLabel(f.name + (f.members ? "  (P2P)" : ""));
		name.setForeground(Color.WHITE);
		name.setFont(FontManager.getRunescapeBoldFont());
		JLabel fresh = new JLabel("● " + ageText(f.ageSeconds));
		fresh.setForeground(ageColor(f.ageSeconds));
		fresh.setFont(FontManager.getRunescapeSmallFont());
		fresh.setHorizontalAlignment(SwingConstants.RIGHT);
		nameLine.add(starButton(f), BorderLayout.WEST);
		nameLine.add(name, BorderLayout.CENTER);
		nameLine.add(fresh, BorderLayout.EAST);
		body.add(nameLine);

		// hero: post-tax profit/item + ROI
		Color profitColor = f.postTaxMargin >= 0 ? ColorScheme.PROGRESS_COMPLETE_COLOR : ColorScheme.PROGRESS_ERROR_COLOR;
		JLabel hero = new JLabel((f.postTaxMargin >= 0 ? "+" : "") + GP.format(f.postTaxMargin)
			+ " gp/item  (" + String.format(Locale.US, "%.1f%%", f.roi) + ")");
		hero.setForeground(profitColor);
		hero.setFont(FontManager.getRunescapeBoldFont());
		hero.setAlignmentX(LEFT_ALIGNMENT);
		body.add(hero);

		// realized gp/hour, colored by freshness confidence; profit/limit alongside it
		Color velColor = f.fillConfidence >= 0.75 ? ColorScheme.PROGRESS_COMPLETE_COLOR
			: f.fillConfidence >= 0.5 ? ColorScheme.PROGRESS_INPROGRESS_COLOR
			: ColorScheme.PROGRESS_ERROR_COLOR;
		String vel = QuantityFormatter.quantityToStackSize((long) f.realizedGpPerHour) + "/h"
			+ (f.fillConfidence < 0.999 ? " (" + Math.round(f.fillConfidence * 100) + "%)" : "");

		body.add(kv("Buy → Sell", GP.format(f.buyPrice) + " → " + GP.format(f.sellPrice), Color.WHITE));
		body.add(kv("gp/hr · /limit", vel + " · " + QuantityFormatter.quantityToStackSize(f.potentialProfit), velColor));
		body.add(kv("Limit · Vol",
			(f.buyLimit > 0 ? GP.format(f.buyLimit) : "—") + " · " + QuantityFormatter.quantityToStackSize(f.dailyVolume),
			Color.WHITE));
		// Thin-volume warning: daily traded volume small relative to the buy limit means your
		// offer may not actually fill the limit — the gp/hour is then more thesis than reality.
		if (f.buyLimit > 0 && f.dailyVolume < (long) f.buyLimit * VOLUME_GATE_FACTOR)
		{
			JLabel thin = new JLabel("⚠ thin volume");
			thin.setForeground(ColorScheme.PROGRESS_INPROGRESS_COLOR);
			thin.setFont(FontManager.getRunescapeSmallFont());
			thin.setAlignmentX(LEFT_ALIGNMENT);
			body.add(thin);
		}
		if (allocQty > 0)
		{
			// Budget plan picked this flip — show how many to buy and the capital it ties up.
			body.add(kv("Allocate", "buy " + GP.format(allocQty)
				+ " · " + QuantityFormatter.quantityToStackSize((long) allocQty * f.buyPrice), ColorScheme.BRAND_ORANGE));
		}
		// Unknown buy limit zeroes the flip's velocity, so don't treat 0 as "alch always wins":
		// compare gp/hour when the flip has a velocity, else fall back to per-item profit.
		boolean alchBeats = f.realizedGpPerHour > 0
			? f.alchGpPerHour > f.realizedGpPerHour
			: f.alchProfit > f.postTaxMargin;
		if (f.alchProfit > 0 && alchBeats)
		{
			// High Alchemy beats this flip — surface it (attention-gated estimate).
			body.add(kv("Alch instead", "+" + GP.format(f.alchProfit) + "/item · "
				+ QuantityFormatter.quantityToStackSize((long) f.alchGpPerHour) + "/h", ALCH_COLOR));
		}

		if (expanded.contains(f.id))
		{
			body.add(Box.createVerticalStrut(3));
			if (sparkLoading.contains(f.id))
			{
				body.add(dim("loading chart…"));
			}
			else
			{
				int[] mids = sparkCache.get(f.id);
				if (mids != null && mids.length >= 2)
				{
					Sparkline sp = new Sparkline(mids, CHART_COLOR, 160, 40);
					sp.setAlignmentX(LEFT_ALIGNMENT);
					body.add(sp);
					body.add(dim("recent price (5m steps)"));
				}
				else
				{
					body.add(dim("no recent price data"));
				}
			}
		}

		// whole-row hover + left-click → expand chart; right-click → menu
		MouseListener ma = new MouseAdapter()
		{
			@Override
			public void mouseClicked(MouseEvent e)
			{
				if (e.getComponent() instanceof JButton)
				{
					return;   // the star handles its own click; don't also open the wiki
				}
				if (javax.swing.SwingUtilities.isLeftMouseButton(e))
				{
					toggleExpand(f);   // expand the price chart; wiki is on the right-click menu
				}
			}

			@Override
			public void mouseEntered(MouseEvent e)
			{
				row.setBackground(ColorScheme.DARKER_GRAY_HOVER_COLOR);
			}

			@Override
			public void mouseExited(MouseEvent e)
			{
				// only un-hover once the pointer has truly left the row (incl. its children)
				if (row.getMousePosition(true) == null)
				{
					row.setBackground(ColorScheme.DARKER_GRAY_COLOR);
				}
			}
		};
		addMouseDeep(row, ma);
		row.setComponentPopupMenu(rowMenu(f));
		inheritPopup(row);

		return row;
	}

	private JButton starButton(FlipItem f)
	{
		boolean fav = plugin.isFavorite(f.id);
		JButton star = new JButton(fav ? "★" : "☆");
		star.setMargin(new java.awt.Insets(0, 0, 0, 0));
		star.setBorder(BorderFactory.createEmptyBorder(0, 0, 0, 4));
		star.setContentAreaFilled(false);
		star.setFocusable(false);
		star.setOpaque(false);
		star.setForeground(fav ? ColorScheme.BRAND_ORANGE : ColorScheme.MEDIUM_GRAY_COLOR);
		star.setFont(FontManager.getRunescapeFont());
		star.setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
		star.setToolTipText(fav ? "Unfavourite" : "Favourite");
		star.addActionListener(e ->
		{
			plugin.toggleFavorite(f.id);
			renderList();
		});
		return star;
	}

	private JPopupMenu rowMenu(FlipItem f)
	{
		JPopupMenu menu = new JPopupMenu();
		JMenuItem price = new JMenuItem("Open price page");
		price.addActionListener(a -> openPricePage(f));
		JMenuItem wiki = new JMenuItem("Open wiki article");
		wiki.addActionListener(a -> LinkBrowser.browse(
			"https://oldschool.runescape.wiki/w/Special:Lookup?type=item&id=" + f.id));
		JMenuItem copyName = new JMenuItem("Copy name");
		copyName.addActionListener(a -> copyToClipboard(f.name));
		JMenuItem copyBuy = new JMenuItem("Copy buy price (" + GP.format(f.buyPrice) + ")");
		copyBuy.addActionListener(a -> copyToClipboard(String.valueOf(f.buyPrice)));
		JMenuItem copySell = new JMenuItem("Copy sell price (" + GP.format(f.sellPrice) + ")");
		copySell.addActionListener(a -> copyToClipboard(String.valueOf(f.sellPrice)));
		menu.add(price);
		menu.add(wiki);
		menu.add(copyName);
		menu.add(copyBuy);
		menu.add(copySell);
		return menu;
	}

	private static void openPricePage(FlipItem f)
	{
		LinkBrowser.browse("https://prices.runescape.wiki/osrs/item/" + f.id);
	}

	private static void copyToClipboard(String text)
	{
		Toolkit.getDefaultToolkit().getSystemClipboard().setContents(new StringSelection(text), null);
	}

	/** Toggle the inline price chart for a row, lazily fetching the series the first time. */
	private void toggleExpand(FlipItem f)
	{
		if (!expanded.remove(f.id))
		{
			expanded.add(f.id);
			if (!sparkCache.containsKey(f.id) && sparkLoading.add(f.id))
			{
				plugin.requestSparkline(f.id, mids ->
				{
					if (disposed)
					{
						return;   // panel torn down before the fetch returned — don't touch it
					}
					sparkLoading.remove(f.id);
					if (mids == null)
					{
						sparkCache.remove(f.id);   // a failure must not stick — allow a retry on re-expand
					}
					else
					{
						sparkCache.put(f.id, mids);
					}
					renderList();
				});
			}
		}
		renderList();
	}

	/** A full-width, transparent, left-aligned BorderLayout cell for BoxLayout rows. */
	private JPanel fullWidth(BorderLayout layout)
	{
		JPanel p = new JPanel(layout)
		{
			@Override
			public Dimension getMaximumSize()
			{
				return new Dimension(Integer.MAX_VALUE, getPreferredSize().height);
			}
		};
		p.setOpaque(false);
		p.setAlignmentX(LEFT_ALIGNMENT);
		return p;
	}

	private JComponent kv(String label, String value, Color valueColor)
	{
		JPanel p = fullWidth(new BorderLayout(6, 0));
		JLabel l = new JLabel(label);
		l.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		l.setFont(FontManager.getRunescapeSmallFont());
		JLabel v = new JLabel(value);
		v.setForeground(valueColor);
		v.setFont(FontManager.getRunescapeSmallFont());
		v.setHorizontalAlignment(SwingConstants.RIGHT);
		p.add(l, BorderLayout.WEST);
		p.add(v, BorderLayout.EAST);
		return p;
	}

	private JComponent dim(String text)
	{
		JLabel l = new JLabel(text);
		l.setForeground(ColorScheme.MEDIUM_GRAY_COLOR);
		l.setFont(FontManager.getRunescapeSmallFont());
		l.setAlignmentX(LEFT_ALIGNMENT);
		return l;
	}

	private static String sortLabel(SalehmanGeConfig.SortBy s)
	{
		switch (s)
		{
			case POTENTIAL_PROFIT: return "Profit / limit";
			case ROI: return "ROI %";
			case MARGIN: return "Margin / item";
			case VELOCITY: return "gp/hour";
			case REALIZED_VELOCITY: return "gp/hour (realized)";
			default: return s.name();
		}
	}

	private static Color ageColor(long s)
	{
		if (s < 0) return ColorScheme.MEDIUM_GRAY_COLOR;
		if (s < 300) return ColorScheme.PROGRESS_COMPLETE_COLOR;     // < 5m
		if (s < 1800) return ColorScheme.PROGRESS_INPROGRESS_COLOR;  // < 30m
		return ColorScheme.PROGRESS_ERROR_COLOR;
	}

	private static String ageText(long s)
	{
		if (s < 0) return "age ?";
		if (s < 60) return s + "s";
		if (s < 3600) return (s / 60) + "m";
		return (s / 3600) + "h";
	}

	private static void addMouseDeep(Container c, MouseListener l)
	{
		// Attach to every descendant (incl. the star button) so hover covers the whole row;
		// the click handler ignores button-originated clicks (see mouseClicked) so the star
		// toggles via its own ActionListener without also opening the wiki.
		c.addMouseListener(l);
		for (Component ch : c.getComponents())
		{
			ch.addMouseListener(l);
			if (ch instanceof Container)
			{
				addMouseDeep((Container) ch, l);
			}
		}
	}

	private static void inheritPopup(Container c)
	{
		for (Component ch : c.getComponents())
		{
			if (ch instanceof JComponent)
			{
				((JComponent) ch).setInheritsPopupMenu(true);
			}
			if (ch instanceof Container)
			{
				inheritPopup((Container) ch);
			}
		}
	}
}
