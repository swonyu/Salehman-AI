package com.salehman.ge;

import java.util.ArrayList;
import java.util.List;
import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import org.junit.Test;

/** Pins the pure mid-price extraction used by the sparkline. */
public class SparklineTest
{
	private GrandExchangeApi.Point pt(Integer hi, Integer lo)
	{
		GrandExchangeApi.Point p = new GrandExchangeApi.Point();
		p.avgHighPrice = hi;
		p.avgLowPrice = lo;
		return p;
	}

	@Test
	public void midsAveragesAndSkipsEmpties()
	{
		List<GrandExchangeApi.Point> pts = new ArrayList<>();
		pts.add(pt(100, 90));     // mid 95
		pts.add(pt(200, null));   // 200 (only high)
		pts.add(pt(null, 50));    // 50 (only low)
		pts.add(pt(null, null));  // skipped (no price)
		pts.add(null);            // skipped (null sample)
		assertArrayEquals(new int[]{95, 200, 50}, Sparkline.mids(pts));
	}

	@Test
	public void midsNullSafe()
	{
		assertEquals(0, Sparkline.mids(null).length);
	}
}
