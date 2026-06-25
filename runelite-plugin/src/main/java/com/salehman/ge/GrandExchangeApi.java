package com.salehman.ge;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonElement;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import javax.inject.Inject;
import javax.inject.Singleton;
import lombok.extern.slf4j.Slf4j;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * Thin client for the community real-time prices API at prices.runescape.wiki.
 * Uses RuneLite's injected {@link OkHttpClient} + {@link Gson} (Plugin Hub rule:
 * don't bundle your own HTTP stack) and identifies itself via the User-Agent, as
 * the wiki asks.
 *
 *  /latest  → instant-buy (high) / instant-sell (low) per item id
 *  /mapping → item id → name / members / 4h buy limit
 *  /24h     → daily traded volume per item id
 */
@Slf4j
@Singleton
public class GrandExchangeApi
{
	private static final String BASE = "https://prices.runescape.wiki/api/v1/osrs";
	static final String UA = "Salehman-GE-Flips RuneLite plugin - contact salehalayed98@gmail.com";

	private final OkHttpClient http;
	private final Gson gson;

	@Inject
	GrandExchangeApi(OkHttpClient http, Gson gson)
	{
		// Reuse RuneLite's shared client (its connection pool / proxy / UA cookie handling)
		// but impose our own timeouts so a hung request can't freeze the refresh forever.
		// newBuilder() shares the same Dispatcher/ConnectionPool, so this is cheap.
		// Null-tolerant: unit tests subclass this with a null client and override the fetches.
		this.http = http == null ? null : http.newBuilder()
			.connectTimeout(10, java.util.concurrent.TimeUnit.SECONDS)
			.readTimeout(20, java.util.concurrent.TimeUnit.SECONDS)
			.callTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
			.build();
		this.gson = gson;
	}

	/** Latest instant-buy/sell prices, keyed by item id. */
	public Map<Integer, Latest> latest() throws IOException
	{
		return fetchDataMap("/latest", Latest.class);
	}

	/** Daily traded volume, keyed by item id. */
	public Map<Integer, Volume> volumes() throws IOException
	{
		return fetchDataMap("/24h", Volume.class);
	}

	/**
	 * Recent price history for one item (for a sparkline). {@code step} is a wiki timestep
	 * such as "5m", "1h", "6h", "24h"; the API returns up to ~365 points.
	 */
	public java.util.List<Point> timeseries(int id, String step) throws IOException
	{
		Request req = request("/timeseries?timestep=" + step + "&id=" + id);
		try (Response resp = http.newCall(req).execute())
		{
			if (!resp.isSuccessful() || resp.body() == null)
			{
				throw new IOException("timeseries HTTP " + resp.code());
			}
			JsonObject root;
			try
			{
				root = gson.fromJson(resp.body().charStream(), JsonObject.class);
			}
			catch (com.google.gson.JsonSyntaxException e)
			{
				throw new IOException("malformed timeseries response", e);
			}
			java.util.List<Point> out = new java.util.ArrayList<>();
			if (root == null || !root.has("data") || !root.get("data").isJsonArray())
			{
				return out;
			}
			for (JsonElement el : root.getAsJsonArray("data"))
			{
				Point p = gson.fromJson(el, Point.class);
				if (p != null)
				{
					out.add(p);
				}
			}
			return out;
		}
	}

	/** Item metadata (name / members / buy limit), keyed by item id. */
	public Map<Integer, Mapping> mapping() throws IOException
	{
		Request req = request("/mapping");
		try (Response resp = http.newCall(req).execute())
		{
			if (!resp.isSuccessful() || resp.body() == null)
			{
				throw new IOException("mapping HTTP " + resp.code());
			}
			Mapping[] arr;
			try
			{
				arr = gson.fromJson(resp.body().charStream(), Mapping[].class);
			}
			catch (com.google.gson.JsonSyntaxException e)
			{
				// Malformed/unexpected body — surface as an IOException so the caller
				// reports a parse problem, not a misleading "connectivity" failure.
				throw new IOException("malformed mapping response", e);
			}
			Map<Integer, Mapping> out = new HashMap<>();
			if (arr != null)
			{
				for (Mapping m : arr)
				{
					// id > 0: gson defaults a missing `id` to 0, which would collide all
					// such entries on key 0 (last-write-wins). No real GE item has id 0.
					if (m != null && m.name != null && m.id > 0)
					{
						out.put(m.id, m);
					}
				}
			}
			return out;
		}
	}

	/** The /latest and /24h endpoints share the {@code {"data": {"<id>": {...}}}} shape. */
	private <T> Map<Integer, T> fetchDataMap(String path, Class<T> type) throws IOException
	{
		Request req = request(path);
		try (Response resp = http.newCall(req).execute())
		{
			if (!resp.isSuccessful() || resp.body() == null)
			{
				throw new IOException(path + " HTTP " + resp.code());
			}
			JsonObject root = gson.fromJson(resp.body().charStream(), JsonObject.class);
			Map<Integer, T> out = new HashMap<>();
			if (root == null || !root.has("data") || !root.get("data").isJsonObject())
			{
				return out;
			}
			for (Map.Entry<String, JsonElement> e : root.getAsJsonObject("data").entrySet())
			{
				try
				{
					out.put(Integer.parseInt(e.getKey()), gson.fromJson(e.getValue(), type));
				}
				catch (NumberFormatException ignored)
				{
					// non-numeric key — skip, never crash the refresh
				}
			}
			return out;
		}
	}

	private Request request(String path)
	{
		return new Request.Builder()
			.url(BASE + path)
			.header("User-Agent", UA)
			.header("Accept", "application/json")
			.build();
	}

	// --- DTOs (Gson sets public fields by reflection; boxed types so null = "no data") ---

	public static class Latest
	{
		public Integer high;     // instant-buy price
		public Long highTime;
		public Integer low;      // instant-sell price
		public Long lowTime;
	}

	public static class Mapping
	{
		public int id;
		public String name;
		public boolean members;
		public Integer limit;    // 4-hour GE buy limit (may be absent)
		public Integer value;
		public Integer highalch; // High Alchemy value (may be absent) — for the alch-vs-flip compare
	}

	public static class Volume
	{
		public Long highPriceVolume;
		public Long lowPriceVolume;
	}

	/** One price-history sample from /timeseries (prices may be null when no trades). */
	public static class Point
	{
		public Long timestamp;
		public Integer avgHighPrice;
		public Integer avgLowPrice;
	}
}
