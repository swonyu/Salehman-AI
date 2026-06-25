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

Per opportunity: **item icon** · name · a colored **profit/item + ROI** hero line ·
**buy → sell** · **gp/hour (realized)** · **profit/limit** · 4h buy limit · daily
volume · a **freshness dot** (how old the quotes are). Click a row to open its live
**wiki price page**; right-click for wiki/copy. A live **"Updated Ns ago"** clock
shows snapshot age.

**Ranking & velocity.** Sort by potential profit, ROI, per-item margin, gp/hour, or
**realized gp/hour** (the default) — gp/hour discounted by a *freshness confidence*
multiplier (1.0 when quotes are fresh, decaying to a 0.25 floor by ~3h) so stale
spreads that won't fill get down-ranked.

**Tools.**
- **Budget allocator** — type your gp (e.g. `100m`) and it plans what to buy, up to
  each item's buy limit, with total profit, gp/hour and a "+X/day if refilled"
  extrapolation, tagging each chosen row. Optional **diversification cap** ("max %
  of budget per item") with a concentration readout.
- **Favourites** — ★ items to pin them to the top (persisted); "★ favourites only"
  filter; live name search.
- **Alch instead** — flags when High Alchemy (highalch − nature − item cost, at
  ~1200 casts/h) beats a flip's realized gp/hour.
- **Price sparkline** — click a row to expand a recent price-history chart.
- **Thin-volume** badge when daily volume is low relative to the buy limit.
- **Auto-refresh** + **notifications** when a flip crosses a gp/hour threshold.
- **In-game overlay** (opt-in) — a draggable on-screen top-flips HUD.
- **Right-click** a row to open the wiki, or copy its name / buy / sell price.

Filter by min margin / min volume / price band / members-only; tax rate + cap and
max quote age are configurable.

> ⚠️ Prices are community-sourced and ~real-time, not official. Flipping is not
> risk-free: prices move, offers don't always fill, and the GE tax + buy limits
> cap returns. "Realized gp/hour", the budget plan, and the alch compare are
> volume-/attention-gated **estimates**, not guarantees. Informational only.

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
- `SalehmanGePlugin` — `@PluginDescriptor`, side panel + nav button, auto-refresh, favourites persistence.
- `SalehmanGeConfig` — user filters (margins, volume, price band, sort, tax rate/cap, auto-refresh).
- `GrandExchangeApi` — fetches `/latest`, `/mapping`, `/24h` from the wiki (Gson + OkHttp; per-call timeouts).
- `FlipFinder` — joins them, applies GE tax + freshness confidence + alch compare, ranks into `FlipItem`s (cached mapping w/ TTL).
- `FlipItem` — immutable ranked-flip value object.
- `BudgetPlanner` — greedy buy-limit-aware capital allocator (the budget plan + diversification cap).
- `Sparkline` — tiny price-history polyline component for the expandable row chart.
- `SalehmanGePanel` — the Swing side panel (icons, budget, search, favourites, sort, click→chart).
- `SalehmanGeOverlay` — opt-in draggable in-game top-flips HUD (`OverlayPanel`).

> Note: `play.sh` / `install-plugin.sh` / `capture-jagex.sh` / `run-local.sh` and the
> `runClient` Gradle task are **local-dev** conveniences (run the plugin in a dev-mode
> client, incl. with a Jagex account). They're not needed for a Plugin Hub submission.
