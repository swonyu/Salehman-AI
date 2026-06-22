# Salehman GE Flips — a RuneLite plugin (Old School RuneScape)

A [RuneLite](https://runelite.net) side-panel that finds the best **Grand Exchange
flips** in real time: it pulls live instant-buy / instant-sell prices, GE buy
limits and daily volume from the community [`prices.runescape.wiki`](https://prices.runescape.wiki/)
API and ranks items by **post-tax margin, ROI, and profit-per-limit** — the OSRS
analogue of "what to buy, for how much, and how much you'll make."

This is the RuneLite extension version of Salehman AI's RuneScape Grand Exchange
feature (the macOS app keeps its own RuneScape tab). Logic mirrors the Swift
`RuneScapeMarketService` / `RuneScapeStore`.

## What it shows

Per opportunity: item · **buy at** (instasell) · **sell at** (instabuy) · margin ·
**GE tax** · **post-tax margin** · **ROI %** · 4h buy limit · daily volume ·
**potential profit** (post-tax margin × buy limit). Sort by potential profit, ROI,
or margin; filter by min margin / min volume / price band / members-only.

> ⚠️ Prices are community-sourced and ~real-time, not official. Flipping is not
> risk-free: prices move, offers don't always fill, and the GE tax + buy limits
> cap returns. Informational only.

## Build

RuneLite plugins are Java 11 + Gradle and depend on the RuneLite client from
`https://repo.runelite.net` (network required — this can't be built in a
restricted sandbox).

```bash
cd runelite-plugin
gradle wrapper           # ONE TIME: generates gradle-wrapper.jar + gradlew/gradlew.bat
                         # (the .properties pinning Gradle 8.7 is already committed;
                         #  the binary jar/scripts can't be committed from CI, so run this once)
./gradlew build          # compiles + runs tests
# Run inside a dev RuneLite client by adding this project as an external plugin,
# or use the runelite/example-plugin gradle run task. See:
# https://github.com/runelite/plugin-hub  (CONTRIBUTING.md)
```

## Submit to the Plugin Hub

Push this folder to its own public GitHub repo, then open a PR against
[`runelite/plugin-hub`](https://github.com/runelite/plugin-hub) adding a manifest
file `plugins/salehman-ge-flips` like:

```
repository=https://github.com/<you>/salehman-ge-flips.git
commit=<full commit sha>
authors=salehman
tags=grand exchange,ge,flip,money,price,merch
description=Live Grand Exchange flip finder — margins, ROI and profit-per-limit from real-time wiki prices.
warning=
```

The Hub CI builds it from that commit. The plugin must keep using RuneLite's
injected `OkHttpClient` and identify itself via the User-Agent (it does — see
`GrandExchangeApi.UA`).

## Files
- `SalehmanGePlugin` — `@PluginDescriptor`, registers the side panel + nav button.
- `SalehmanGeConfig` — user filters (margins, volume, price band, sort, tax rate/cap).
- `GrandExchangeApi` — fetches `/latest`, `/mapping`, `/24h` from the wiki (Gson + OkHttp).
- `FlipFinder` — joins them, applies the GE tax, filters + ranks into `FlipItem`s.
- `SalehmanGePanel` — the Swing side panel (refresh + ranked rows + disclaimer).
