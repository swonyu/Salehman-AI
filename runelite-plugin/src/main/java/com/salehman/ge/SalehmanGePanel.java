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

	private final SalehmanGePlugin plugin;
	private final ItemManager itemManager;
	private final JPanel list = new JPanel();
	private final JLabel status = new JLabel("Tap Refresh to find flips.");
	private final JLabel updated = new JLabel(" ");
	private final JButton refresh = new JButton("Refresh");
	private final javax.swing.JTextField budgetField = new javax.swing.JTextField();
	private final Timer clock = new Timer(1000, e -> tickUpdated());

	private long lastUpdatedMs = -1;
	private long budget = 0;
	private java.util.List<FlipItem> lastFlips = java.util.Collections.emptyList();

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

	/** Stop the live-updated clock so a disabled panel doesn't leak a running Timer. */
	void stopClock()
	{
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
			status.setText(flips.size() + " flips · ranked");
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
				BudgetPlanner.BudgetPlan plan = BudgetPlanner.plan(lastFlips, budget);
				list.add(planSummary(plan));
				list.add(Box.createVerticalStrut(6));
				alloc = new java.util.HashMap<>();
				for (BudgetPlanner.Allocation a : plan.allocations)
				{
					alloc.put(a.flip.id, a.quantity);
				}
			}
			for (FlipItem f : lastFlips)
			{
				list.add(row(f, alloc.getOrDefault(f.id, 0)));
				list.add(Box.createVerticalStrut(6));
			}
		}
		list.revalidate();
		list.repaint();
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
		JComponent spend = kv("Spend", QuantityFormatter.quantityToStackSize(plan.capitalUsed)
			+ " · " + plan.allocations.size() + " items", Color.WHITE);
		spend.setAlignmentX(LEFT_ALIGNMENT);
		p.add(spend);
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
		if (allocQty > 0)
		{
			// Budget plan picked this flip — show how many to buy and the capital it ties up.
			body.add(kv("Allocate", "buy " + GP.format(allocQty)
				+ " · " + QuantityFormatter.quantityToStackSize((long) allocQty * f.buyPrice), ColorScheme.BRAND_ORANGE));
		}

		// whole-row hover + left-click → wiki price page; right-click → menu
		MouseListener ma = new MouseAdapter()
		{
			@Override
			public void mouseClicked(MouseEvent e)
			{
				if (javax.swing.SwingUtilities.isLeftMouseButton(e))
				{
					openPricePage(f);
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

	private JPopupMenu rowMenu(FlipItem f)
	{
		JPopupMenu menu = new JPopupMenu();
		JMenuItem price = new JMenuItem("Open price page");
		price.addActionListener(a -> openPricePage(f));
		JMenuItem wiki = new JMenuItem("Open wiki article");
		wiki.addActionListener(a -> LinkBrowser.browse(
			"https://oldschool.runescape.wiki/w/Special:Lookup?type=item&id=" + f.id));
		JMenuItem copy = new JMenuItem("Copy name");
		copy.addActionListener(a -> Toolkit.getDefaultToolkit().getSystemClipboard()
			.setContents(new StringSelection(f.name), null));
		menu.add(price);
		menu.add(wiki);
		menu.add(copy);
		return menu;
	}

	private static void openPricePage(FlipItem f)
	{
		LinkBrowser.browse("https://prices.runescape.wiki/osrs/item/" + f.id);
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
