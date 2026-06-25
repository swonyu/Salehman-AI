package com.salehman.ge;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import org.junit.Test;

/** Pins the pure notification gating (prime / dedup / cap / re-arm) without RuneLite deps. */
public class NotifyTest
{
	private FlipItem fi(int id, double realizedGpPerHour)
	{
		return new FlipItem(id, "i" + id, 0, 0, 0, 0, 0, 0.0, 0, 0L, 0L, 0.0,
			realizedGpPerHour, 1.0, 0, 0.0, false, -1L);
	}

	private List<Integer> ids(List<FlipItem> fs)
	{
		return fs.stream().map(f -> f.id).collect(Collectors.toList());
	}

	@Test
	public void firstPassPrimesSilently()
	{
		Set<Integer> notified = new HashSet<>();
		List<FlipItem> flips = Arrays.asList(fi(1, 100), fi(2, 50));   // only 1 is ≥ 60
		List<FlipItem> fire = SalehmanGePlugin.selectNotifications(flips, 60, notified, true, 3);
		assertTrue("first pass is a silent baseline", fire.isEmpty());
		assertEquals(new HashSet<>(Arrays.asList(1)), notified);
	}

	@Test
	public void firesNewCrossersDedupedAndCapped()
	{
		Set<Integer> notified = new HashSet<>(Arrays.asList(1));   // 1 already alerted
		List<FlipItem> flips = Arrays.asList(fi(1, 100), fi(2, 80), fi(3, 70), fi(4, 90));
		List<FlipItem> fire = SalehmanGePlugin.selectNotifications(flips, 60, notified, false, 3);
		assertEquals(Arrays.asList(2, 3, 4), ids(fire));          // 1 deduped, 2/3/4 are new
		assertEquals(new HashSet<>(Arrays.asList(1, 2, 3, 4)), notified);
	}

	@Test
	public void capLimitsBurstAndLeavesRestForNextPass()
	{
		Set<Integer> notified = new HashSet<>();
		List<FlipItem> flips = new ArrayList<>();
		for (int i = 1; i <= 5; i++)
		{
			flips.add(fi(i, 100));
		}
		List<FlipItem> fire = SalehmanGePlugin.selectNotifications(flips, 60, notified, false, 2);
		assertEquals(Arrays.asList(1, 2), ids(fire));            // capped at 2
		List<FlipItem> next = SalehmanGePlugin.selectNotifications(flips, 60, notified, false, 2);
		assertEquals(Arrays.asList(3, 4), ids(next));            // 3/4 next pass; 5 the pass after
	}

	@Test
	public void reArmsWhenItemDropsOutThenReCrosses()
	{
		Set<Integer> notified = new HashSet<>(Arrays.asList(1, 2));   // both previously alerted
		// pass where item 2 has left the list entirely; 1 still hot
		List<FlipItem> fire = SalehmanGePlugin.selectNotifications(Arrays.asList(fi(1, 100)), 60, notified, false, 3);
		assertTrue(fire.isEmpty());                               // 1 deduped
		assertEquals(new HashSet<>(Arrays.asList(1)), notified);  // 2 re-armed (snapshot retainAll)
		// 2 re-enters above threshold → alerts again
		List<FlipItem> again = SalehmanGePlugin.selectNotifications(Arrays.asList(fi(1, 100), fi(2, 100)), 60, notified, false, 3);
		assertEquals(Arrays.asList(2), ids(again));
	}
}
