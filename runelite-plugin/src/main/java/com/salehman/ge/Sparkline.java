package com.salehman.ge;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.util.Arrays;
import java.util.List;
import javax.swing.JComponent;

/** Tiny price-history sparkline: a normalized polyline of mid prices. */
class Sparkline extends JComponent
{
	private final int[] values;
	private final Color line;

	Sparkline(int[] values, Color line, int width, int height)
	{
		this.values = values;
		this.line = line;
		setPreferredSize(new Dimension(width, height));
		setMaximumSize(new Dimension(Integer.MAX_VALUE, height));
		setOpaque(false);
	}

	/**
	 * Mid price per sample (avg of high/low, or whichever leg is present); samples with no
	 * price at all are skipped. Pure + null-safe so it can be unit-tested.
	 */
	static int[] mids(List<GrandExchangeApi.Point> points)
	{
		if (points == null)
		{
			return new int[0];
		}
		int[] tmp = new int[points.size()];
		int n = 0;
		for (GrandExchangeApi.Point p : points)
		{
			if (p == null)
			{
				continue;
			}
			Integer hi = p.avgHighPrice;
			Integer lo = p.avgLowPrice;
			if (hi != null && lo != null)
			{
				tmp[n++] = (int) (((long) hi + lo) / 2);
			}
			else if (hi != null)
			{
				tmp[n++] = hi;
			}
			else if (lo != null)
			{
				tmp[n++] = lo;
			}
		}
		return Arrays.copyOf(tmp, n);
	}

	@Override
	protected void paintComponent(Graphics g)
	{
		super.paintComponent(g);
		if (values.length < 2)
		{
			return;
		}
		int w = getWidth();
		int h = getHeight();
		int min = values[0];
		int max = values[0];
		for (int v : values)
		{
			if (v < min)
			{
				min = v;
			}
			if (v > max)
			{
				max = v;
			}
		}
		int range = Math.max(1, max - min);
		Graphics2D g2 = (Graphics2D) g.create();
		g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
		g2.setColor(line);
		int n = values.length;
		int prevX = 0;
		int prevY = y(values[0], min, range, h);
		for (int i = 1; i < n; i++)
		{
			int x = (int) ((long) i * (w - 1) / (n - 1));
			int yy = y(values[i], min, range, h);
			g2.drawLine(prevX, prevY, x, yy);
			prevX = x;
			prevY = yy;
		}
		g2.dispose();
	}

	private static int y(int v, int min, int range, int h)
	{
		// higher price → higher on screen (smaller y)
		return (h - 1) - (int) ((long) (v - min) * (h - 1) / range);
	}
}
