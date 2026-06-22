package com.salehman.ge;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Dimension;
import java.awt.GridLayout;
import java.text.NumberFormat;
import java.util.List;
import java.util.Locale;
import javax.swing.BorderFactory;
import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;
import net.runelite.client.ui.ColorScheme;
import net.runelite.client.ui.FontManager;
import net.runelite.client.ui.PluginPanel;

/** The side panel: a refresh button, ranked flip rows, and an honest disclaimer. */
class SalehmanGePanel extends PluginPanel
{
	private static final NumberFormat GP = NumberFormat.getIntegerInstance(Locale.US);

	private final SalehmanGePlugin plugin;
	private final JPanel list = new JPanel();
	private final JLabel status = new JLabel("Tap Refresh to find flips.");
	private final JButton refresh = new JButton("Refresh");

	SalehmanGePanel(SalehmanGePlugin plugin)
	{
		this.plugin = plugin;
		setLayout(new BorderLayout(0, 8));
		setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));

		JPanel header = new JPanel(new BorderLayout(0, 6));
		header.setBackground(ColorScheme.DARK_GRAY_COLOR);

		JLabel title = new JLabel("Grand Exchange Flips");
		title.setFont(FontManager.getRunescapeBoldFont());
		title.setForeground(Color.WHITE);
		header.add(title, BorderLayout.NORTH);

		refresh.setFocusable(false);
		refresh.addActionListener(e -> plugin.refresh());
		header.add(refresh, BorderLayout.CENTER);

		status.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		status.setFont(FontManager.getRunescapeSmallFont());
		header.add(status, BorderLayout.SOUTH);
		add(header, BorderLayout.NORTH);

		list.setLayout(new BoxLayout(list, BoxLayout.Y_AXIS));
		list.setBackground(ColorScheme.DARK_GRAY_COLOR);
		add(list, BorderLayout.CENTER);

		JLabel disclaimer = new JLabel("<html>Community ~real-time prices, not official. "
			+ "Flipping isn't risk-free — offers may not fill and prices move. Informational only.</html>");
		disclaimer.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		disclaimer.setFont(FontManager.getRunescapeSmallFont());
		add(disclaimer, BorderLayout.SOUTH);
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
		status.setText(message);
	}

	void setFlips(List<FlipItem> flips)
	{
		setLoading(false);
		list.removeAll();
		if (flips.isEmpty())
		{
			status.setText("No flips match your filters.");
		}
		else
		{
			status.setText(flips.size() + " flips · ranked");
			for (FlipItem f : flips)
			{
				list.add(row(f));
				list.add(Box.createVerticalStrut(6));
			}
		}
		list.revalidate();
		list.repaint();
	}

	private JPanel row(FlipItem f)
	{
		JPanel row = new JPanel(new BorderLayout(6, 2));
		row.setBackground(ColorScheme.DARKER_GRAY_COLOR);
		row.setBorder(BorderFactory.createEmptyBorder(6, 8, 6, 8));
		row.setMaximumSize(new Dimension(Integer.MAX_VALUE, 76));

		String age = f.ageSeconds >= 0 ? "  · " + (f.ageSeconds / 60) + "m old" : "";
		JLabel name = new JLabel(f.name + (f.members ? "  (P2P)" : "") + age);
		name.setForeground(Color.WHITE);
		name.setFont(FontManager.getRunescapeBoldFont());
		row.add(name, BorderLayout.NORTH);

		JPanel grid = new JPanel(new GridLayout(3, 2, 8, 0));
		grid.setBackground(ColorScheme.DARKER_GRAY_COLOR);
		grid.add(metric("Buy", GP.format(f.buyPrice), ColorScheme.LIGHT_GRAY_COLOR));
		grid.add(metric("Sell", GP.format(f.sellPrice), ColorScheme.LIGHT_GRAY_COLOR));
		grid.add(metric("Profit/item",
			GP.format(f.postTaxMargin) + " (" + String.format(Locale.US, "%.1f", f.roi) + "%)",
			f.postTaxMargin >= 0 ? ColorScheme.PROGRESS_COMPLETE_COLOR : ColorScheme.PROGRESS_ERROR_COLOR));
		grid.add(metric("Profit/limit", GP.format(f.potentialProfit), ColorScheme.PROGRESS_COMPLETE_COLOR));
		// MONEY VELOCITY: gp/hour ranks fastest-compounding flips (estimate; assumes you
		// fill the 4h buy limit). Mirrors the macOS app's StockSageGEFlip.
		grid.add(metric("gp/hour", GP.format((long) f.gpPerHour), ColorScheme.PROGRESS_COMPLETE_COLOR));
		grid.add(metric("Buy limit", f.buyLimit > 0 ? String.valueOf(f.buyLimit) : "—",
			ColorScheme.LIGHT_GRAY_COLOR));
		row.add(grid, BorderLayout.CENTER);

		return row;
	}

	private JPanel metric(String label, String value, Color valueColor)
	{
		JPanel p = new JPanel(new BorderLayout());
		p.setBackground(ColorScheme.DARKER_GRAY_COLOR);
		JLabel l = new JLabel(label);
		l.setForeground(ColorScheme.LIGHT_GRAY_COLOR);
		l.setFont(FontManager.getRunescapeSmallFont());
		JLabel v = new JLabel(value);
		v.setForeground(valueColor);
		v.setFont(FontManager.getRunescapeSmallFont());
		p.add(l, BorderLayout.NORTH);
		p.add(v, BorderLayout.SOUTH);
		return p;
	}
}
