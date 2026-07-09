# StockSage Verified Universe — 1,024 names (draft for research/UNIVERSE_VERIFIED_2026-07-03.md)

**Verified:** 2026-07-09 (UTC) — every row fetched through the app's OWN Yahoo v8 path
(`query1.finance.yahoo.com/v8/finance/chart/<sym>?range=1d&interval=1d`, exact
`StockSageQuoteService.ua`, HTTP 200 + parseable `meta.regularMarketPrice > 0` — QuoteService.swift:51/:93/:138 @ HEAD 0416f79).
**Candidate pool:** `research/UNIVERSE_CANDIDATES_2026-07-03.md` (1,413 rows, constituents as-of 2026-07-03, live-sourced, never model memory).
**Method:** gentle sequential verification ~1 req/2s, exponential backoff on 429 (30s/60s), hard-abort budget 3×429 (used: 0);
429 treated as throttle never falsity; non-429 failures re-tried once then replaced by ranked backfill.
**Kept core:** 209 of the 210 current `StockSageUniverse.groups` symbols re-verified (indices/FX/crypto included); **ROG.SW DROPPED** — persistent HTTP 404 on the app's own path (retried + re-probed 3×, 2026-07-09): dead on Yahoo, and it fails every LIVE production scan today (StockSageQuoteService:355), so the drop is a bug fix, ruled under the 2026-07-09 owner gate-lift. The **815 additions** (quota raised 814→815 to keep the total at exactly 1,024) are all equities.
**Fetch stack note:** requests issued via `universe_fetch.swift` (URLSession/CFNetwork, the exact `StockSageQuoteService` UA/URL/parse) — python urllib draws stack-fingerprint 429s on `.SR` that the app's own network stack does not (measured 429-vs-200 same-minute, 2026-07-09).

## Current-210 subset check
- 209/210 current core symbols present and fetchVerified=true; 1 documented drop (ROG.SW, persistent 404 — see header). No unruled core failure.

## Ranked backfill notes
- Candidate walk order = the candidates file's ranked order (Saudi first, then S&P 500, Nasdaq-100, S&P MidCap 400, FTSE 100, DAX 40, EURO STOXX 50, Nikkei 225).
- 0 candidate(s) failed verification and were passed over; each slot filled by the next ranked candidate:

## Fetch timing (measured, app v8 path)
- measured: 2026-07-09T06:21:25Z, throttle state: unblocked since 2026-07-09T05:42:40Z (first 200 at 2026-07-09T05:42:40Z; orchestrator .KS/.HK/.T probes were 200 before this run)
- concurrency=6: N=209, p50=0.314s, p90=0.356s, rate429=0.0%
- (supplementary, sequential c=1 over the full 1024-request verification pass: p50=0.33s, p90=0.379s, rate429=0.0% of 1025 symbols)

| Yahoo symbol | Name | Exchange | Market group | fetchVerified | source URL | as-of |
|---|---|---|---|---|---|---|
| 2222.SR | Saudi Arabian Oil Company (Aramco) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1120.SR | Al Rajhi Banking and Investment Corporation | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 7010.SR | Saudi Telecom Company (STC) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2010.SR | Saudi Basic Industries Corporation (SABIC) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1180.SR | The Saudi National Bank | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2350.SR | Saudi Kayan Petrochemical Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1010.SR | Riyad Bank | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1060.SR | Saudi Awwal Bank (SAB) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1150.SR | Alinma Bank | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1080.SR | Arab National Bank | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1140.SR | Bank Albilad | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1211.SR | Saudi Arabian Mining Company (Maaden) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2020.SR | SABIC Agri-Nutrients Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2290.SR | Yanbu National Petrochemical Company (Yansab) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2380.SR | Rabigh Refining and Petrochemical Company (Petro Rabigh) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2330.SR | Advanced Petrochemical Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 7020.SR | Etihad Etisalat Company (Mobily) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 7030.SR | Mobile Telecommunications Company Saudi Arabia (Zain KSA) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2280.SR | Almarai Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4190.SR | Jarir Marketing Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 6010.SR | The National Agricultural Development Company (NADEC) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 5110.SR | Saudi Electricity Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4030.SR | The National Shipping Company of Saudi Arabia (Bahri) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4013.SR | Dr. Sulaiman Al Habib Medical Services Group Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4014.SR | Scientific and Medical Equipmen | Saudi | 🇸🇦 Tadawul (TASI) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 8010.SR | The Company for Cooperative Insurance (Tawuniya) | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 8210.SR | Bupa Arabia for Cooperative Insurance Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 3030.SR | Saudi Cement Company | Tadawul | 🇸🇦 Tadawul (TASI) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| AAPL | Apple Inc. (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MSFT | Microsoft (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| NVDA | Nvidia (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| GOOGL | Alphabet Inc. (Class A) (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| AMZN | Amazon (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| META | Meta Platforms (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| AVGO | Broadcom (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| TSLA | Tesla, Inc. (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ORCL | Oracle Corporation | NYSE/Nasdaq | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AMD | Advanced Micro Devices (also: S&P 500) | NASDAQ | 🇺🇸 US Mega-cap Tech | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| INTC | Intel (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| QCOM | Qualcomm (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| TXN | Texas Instruments (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MU | Micron Technology (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| AMAT | Applied Materials (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ADI | Analog Devices (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| LRCX | Lam Research (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| KLAC | KLA Corporation (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CSCO | Cisco (also: S&P 500) | NASDAQ | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| IBM | IBM | NYSE/Nasdaq | 🇺🇸 US Semis & Hardware | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CRM | Salesforce | NYSE/Nasdaq | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ADBE | Adobe Inc. (also: S&P 500) | NASDAQ | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| NOW | ServiceNow | NYSE/Nasdaq | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| INTU | Intuit (also: S&P 500) | NASDAQ | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| PANW | Palo Alto Networks (also: S&P 500) | NASDAQ | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| SNPS | Synopsys (also: S&P 500) | NASDAQ | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CDNS | Cadence Design Systems (also: S&P 500) | NASDAQ | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| NFLX | Netflix, Inc. (also: S&P 500) | NASDAQ | 🇺🇸 US Software | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| JPM | JPMorgan Chase | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BAC | Bank of America | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WFC | Wells Fargo | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GS | Goldman Sachs | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MS | Morgan Stanley | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| C | Citigroup | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BLK | BlackRock | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SCHW | Charles Schwab Corporation | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AXP | American Express | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| V | Visa Inc. | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MA | Mastercard | NYSE/Nasdaq | 🇺🇸 US Financials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| UNH | UnitedHealth Group | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| JNJ | Johnson & Johnson | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LLY | Lilly (Eli) | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PFE | Pfizer | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MRK | Merck & Co. | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ABBV | AbbVie | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TMO | Thermo Fisher Scientific | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ABT | Abbott Laboratories | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DHR | Danaher Corporation | NYSE/Nasdaq | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AMGN | Amgen (also: S&P 500) | NASDAQ | 🇺🇸 US Health | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| HD | Home Depot (The) | NYSE/Nasdaq | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MCD | McDonald's | NYSE/Nasdaq | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NKE | Nike, Inc. | NYSE/Nasdaq | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SBUX | Starbucks (also: S&P 500) | NASDAQ | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| COST | Costco (also: S&P 500) | NASDAQ | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| WMT | Walmart (also: S&P 500) | NASDAQ | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| PG | Procter & Gamble | NYSE/Nasdaq | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KO | Coca-Cola Company (The) | NYSE/Nasdaq | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PEP | PepsiCo (also: S&P 500) | NASDAQ | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| DIS | Walt Disney Company (The) | NYSE/Nasdaq | 🇺🇸 US Consumer | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| XOM | ExxonMobil | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CVX | Chevron Corporation | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| COP | ConocoPhillips | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BA | Boeing | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CAT | Caterpillar Inc. | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GE | GE Aerospace | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HON | Honeywell (also: S&P 500) | NASDAQ | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| UPS | United Parcel Service | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RTX | RTX Corporation | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LMT | Lockheed Martin | NYSE/Nasdaq | 🇺🇸 US Energy & Industrials | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SPY | State Street SPDR S&P 500 ETF T | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| QQQ | Invesco QQQ Trust, Series 1 | NasdaqGM | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| DIA | State Street SPDR Dow Jones Ind | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| IWM | iShares Russell 2000 Index Fund | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| VTI | Vanguard Total Stock Market ETF | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| XLK | State Street Technology Select  | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| XLF | State Street Financial Select S | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| XLE | State Street Energy Select Sect | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| XLV | State Street Health Care Select | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| GLD | SPDR Gold Shares | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| SLV | iShares Silver Trust | NYSEArca | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| TLT | iShares 20+ Year Treasury Bond  | NasdaqGM | 📊 ETFs (broad & sector) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| SHEL.L | Shell plc | LSE | 🇬🇧 London (LSE) | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-09 |
| AZN.L | AstraZeneca | LSE | 🇬🇧 London (LSE) | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-09 |
| HSBA.L | HSBC | LSE | 🇬🇧 London (LSE) | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-09 |
| ULVR.L | Unilever | LSE | 🇬🇧 London (LSE) | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-09 |
| BP.L | BP | LSE | 🇬🇧 London (LSE) | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-09 |
| GSK.L | GSK plc | LSE | 🇬🇧 London (LSE) | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-09 |
| SAP.DE | SAP (also: EURO STOXX 50) | Xetra | 🇩🇪 Frankfurt (XETRA) | true | https://en.wikipedia.org/wiki/DAX | 2026-07-09 |
| SIE.DE | Siemens (also: EURO STOXX 50) | Xetra | 🇩🇪 Frankfurt (XETRA) | true | https://en.wikipedia.org/wiki/DAX | 2026-07-09 |
| ALV.DE | Allianz (also: EURO STOXX 50) | Xetra | 🇩🇪 Frankfurt (XETRA) | true | https://en.wikipedia.org/wiki/DAX | 2026-07-09 |
| BMW.DE | BMW (also: EURO STOXX 50) | Xetra | 🇩🇪 Frankfurt (XETRA) | true | https://en.wikipedia.org/wiki/DAX | 2026-07-09 |
| MC.PA | LVMH | Euronext Paris | 🇫🇷 Paris (Euronext) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| OR.PA | L'Oréal | Euronext Paris | 🇫🇷 Paris (Euronext) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| AIR.PA | Airbus (also: EURO STOXX 50) | Euronext Paris | 🇫🇷 Paris (Euronext) | true | https://en.wikipedia.org/wiki/DAX | 2026-07-09 |
| TTE.PA | TotalEnergies | Euronext Paris | 🇫🇷 Paris (Euronext) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| 7203.T | Toyota Motor | Tokyo | 🇯🇵 Tokyo (TSE) | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-09 |
| 6758.T | Sony Group | Tokyo | 🇯🇵 Tokyo (TSE) | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-09 |
| 9984.T | SoftBank Group | Tokyo | 🇯🇵 Tokyo (TSE) | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-09 |
| 8306.T | Mitsubishi UFJ Financial Group | Tokyo | 🇯🇵 Tokyo (TSE) | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-09 |
| 0700.HK | TENCENT | HKSE | 🇭🇰 Hong Kong (HKEX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 9988.HK | BABA-W | HKSE | 🇭🇰 Hong Kong (HKEX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 3690.HK | MEITUAN-W | HKSE | 🇭🇰 Hong Kong (HKEX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 600519.SS | KWEICHOW MOUTAI | Shanghai | 🇨🇳 Shanghai (SSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 005930.KS | SamsungElec | KSE | 🇰🇷 Seoul (KRX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 000660.KS | SK hynix | KSE | 🇰🇷 Seoul (KRX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| RELIANCE.NS | RELIANCE INDUSTRIES LTD | NSE | 🇮🇳 Mumbai (NSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| TCS.NS | TATA CONSULTANCY SERV LT | NSE | 🇮🇳 Mumbai (NSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| INFY.NS | INFOSYS LIMITED | NSE | 🇮🇳 Mumbai (NSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| HDFCBANK.NS | HDFC BANK LTD | NSE | 🇮🇳 Mumbai (NSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 2330.TW | TAIWAN SEMICONDUCTOR MANUFACTUR | Taiwan | 🇹🇼 Taiwan (TWSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 2317.TW | HON HAI PRECISION INDUSTRY | Taiwan | 🇹🇼 Taiwan (TWSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| D05.SI | DBS | SES | 🇸🇬 Singapore (SGX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| O39.SI | OCBC Bank | SES | 🇸🇬 Singapore (SGX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| BHP.AX | BHP GROUP FPO [BHP] | ASX | 🇦🇺 Sydney (ASX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| CBA.AX | CWLTH BANK FPO [CBA] | ASX | 🇦🇺 Sydney (ASX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| CSL.AX | CSL FPO [CSL] | ASX | 🇦🇺 Sydney (ASX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| PETR4.SA | PETROBRAS   PN      N2 | São Paulo | 🇧🇷 São Paulo (B3) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| VALE3.SA | VALE        ON      NM | São Paulo | 🇧🇷 São Paulo (B3) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ITUB4.SA | ITAUUNIBANCOPN  EJ  N1 | São Paulo | 🇧🇷 São Paulo (B3) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| AMXB.MX | AMERICA MOVIL SAB DE CV | Mexico | 🇲🇽 Mexico (BMV) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| WALMEX.MX | WAL-MART DE MEXICO SAB DE CV | Mexico | 🇲🇽 Mexico (BMV) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| RY.TO | ROYAL BANK OF CANADA | Toronto | 🇨🇦 Toronto (TSX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| SHOP.TO | SHOPIFY INC | Toronto | 🇨🇦 Toronto (TSX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ENB.TO | ENBRIDGE INC | Toronto | 🇨🇦 Toronto (TSX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| NESN.SW | NESTLE N | Swiss | 🇨🇭 Zurich (SIX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| NOVN.SW | NOVARTIS N | Swiss | 🇨🇭 Zurich (SIX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ASML.AS | ASML Holding | Euronext Amsterdam | 🇳🇱 Amsterdam (Euronext) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| ADYEN.AS | Adyen | Euronext Amsterdam | 🇳🇱 Amsterdam (Euronext) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| SAN.MC | Banco Santander | Bolsa de Madrid | 🇪🇸 Madrid (BME) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| IBE.MC | Iberdrola | Bolsa de Madrid | 🇪🇸 Madrid (BME) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| ITX.MC | Inditex | Bolsa de Madrid | 🇪🇸 Madrid (BME) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| ENI.MI | Eni | Borsa Italiana | 🇮🇹 Milan (Borsa) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| ISP.MI | Intesa Sanpaolo | Borsa Italiana | 🇮🇹 Milan (Borsa) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| RACE.MI | Ferrari | Borsa Italiana | 🇮🇹 Milan (Borsa) | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-09 |
| VOLV-B.ST | Volvo, AB ser. B | Stockholm | 🇸🇪 Stockholm (OMX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ERIC-B.ST | Ericsson, Telefonab. L M ser. B | Stockholm | 🇸🇪 Stockholm (OMX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| EMAAR.AE | EMAAR PROPERTIES | Dubai | 🇦🇪 Dubai (DFM) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| DEWA.AE | DUBAI ELECTRICITY | Dubai | 🇦🇪 Dubai (DFM) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| QNBK.QA | QATAR NATIONAL BANK | Qatar | 🇶🇦 Qatar (QSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| IQCD.QA | INDUSTRIES OF QATAR | Qatar | 🇶🇦 Qatar (QSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| QIBK.QA | QATAR ISLAMIC BANK | Qatar | 🇶🇦 Qatar (QSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| MARK.QA | ALRAYAN BANK | Qatar | 🇶🇦 Qatar (QSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| COMI.CA | COMI.CA,0P0000AUZ4,5721726 | EGX | 🇪🇬 Egypt (EGX) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| NPN.JO | Naspers Ltd -N- | Johannesburg | 🇿🇦 Johannesburg (JSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| AGL.JO | Anglo American plc | Johannesburg | 🇿🇦 Johannesburg (JSE) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^GSPC | S&P 500 | SNP | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^IXIC | NASDAQ Composite | Nasdaq GIDS | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^DJI | Dow Jones Industrial Average | DJI | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^RUT | Russell 2000 | Chicago Options | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^VIX | CBOE Volatility Index | Cboe Indices | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^FTSE | FTSE 100 | FTSE Index | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^GDAXI | DAX                           P | XETRA | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^FCHI | CAC 40 | Paris | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^STOXX50E | EURO STOXX 50                 I | Zurich | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^N225 | Nikkei 225 | Osaka | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^HSI | HANG SENG INDEX | HKSE | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^NSEI | NIFTY 50 | NSE | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^TWII | TSEC CAPITALIZATION WEIGHTED ST | Taiwan | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^STI | STI Index | SES | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^BVSP | IBOVESPA | São Paulo | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^AXJO | S&P/ASX 200 [XJO] | ASX | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^GSPTSE | S&P/TSX Composite index | Toronto | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ^TASI.SR | Tadawul All Shares Index | Saudi | 🌍 World indices | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| EURUSD=X | EUR/USD | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| GBPUSD=X | GBP/USD | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| USDJPY=X | USD/JPY | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| USDSAR=X | USD/SAR | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| USDCNY=X | USD/CNY | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| AUDUSD=X | AUD/USD | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| USDCAD=X | USD/CAD | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| USDCHF=X | USD/CHF | CCY | 💱 Forex (24×5) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| BTC-USD | Bitcoin USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ETH-USD | Ethereum USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| SOL-USD | Solana USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| XRP-USD | XRP USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| BNB-USD | BNB USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| ADA-USD | Cardano USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| DOGE-USD | Dogecoin USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| AVAX-USD | Avalanche USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| DOT-USD | Polkadot USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| LINK-USD | Chainlink USD | CCC | ₿ Crypto (24/7) | true | repo://Salehman AI/StockSage/StockSageQuoteService.swift@0416f79 (current core, kept per owner design) | 2026-07-09 |
| 1020.SR | Bank Aljazira | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1030.SR | The Saudi Investment Bank | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1050.SR | Banque Saudi Fransi | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1111.SR | Saudi Tadawul Group Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1212.SR | Astra Industrial Group Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1303.SR | Electrical Industries Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1321.SR | East Pipes Integrated Company for Industry | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1322.SR | Al Masane Al Kobra Mining Company (AMAK) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1810.SR | Seera Holding Group | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 1830.SR | Leejam Sports Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2050.SR | Savola Group Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2060.SR | National Industrialization Company (Tasnee) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2070.SR | Saudi Pharmaceutical Industries and Medical Appliances Corporation (SPIMACO) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2080.SR | National Gas and Industrialization Company (GASCO) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2081.SR | Alkhorayef Water and Power Technologies Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2082.SR | ACWA Power Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2083.SR | Power and Water Utility Company for Jubail and Yanbu (Marafiq) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2223.SR | Saudi Aramco Base Oil Company - Luberef | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2230.SR | Saudi Chemical Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2250.SR | Saudi Industrial Investment Group | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2270.SR | Saudia Dairy & Foodstuff Company (SADAFCO) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2310.SR | Sahara International Petrochemical Company (Sipchem) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2320.SR | Al-Babtain Power and Telecommunications Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2381.SR | Arabian Drilling Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 2382.SR | ADES Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 3020.SR | YAMAMA Cement Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 3040.SR | Qassim Cement Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4001.SR | Abdullah Al-Othaim Markets Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4002.SR | Mouwasat Medical Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4003.SR | United Electronics Company (eXtra) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4004.SR | Dallah Healthcare Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4005.SR | National Medical Care Company (Care) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4007.SR | Al Hammadi Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4015.SR | Jamjoom Pharmaceuticals Factory Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4017.SR | Dr. Soliman Abdel Kader Fakeeh Hospital Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4018.SR | Almoosa Health Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4019.SR | Specialized Medical Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4020.SR | Saudi Real Estate Company (Al Akaria) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4031.SR | Saudi Ground Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4071.SR | Arabian Contracting Services Company (Al Arabia) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4072.SR | MBC Group | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4084.SR | Derayah Financial Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4090.SR | Taiba Investment Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4100.SR | Makkah Construction and Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4142.SR | Riyadh Cables Group Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4150.SR | Arriyadh Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4161.SR | BinDawood Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4162.SR | Almunajem Foods Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4163.SR | Al-Dawaa Medical Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4164.SR | Nahdi Medical Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4165.SR | Al Majed for Oud Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4200.SR | Aldrees Petroleum and Transport Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4210.SR | Saudi Research and Media Group (SRMG) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4220.SR | Emaar The Economic City | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4250.SR | Jabal Omar Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4260.SR | United International Transportation Company (Budget Saudi) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4263.SR | SAL Saudi Logistics Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4264.SR | Flynas Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4280.SR | Kingdom Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4291.SR | National Company for Learning and Education | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4300.SR | Dar Al Arkan Real Estate Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4310.SR | Knowledge Economic City Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4321.SR | Arabian Centres Company (Cenomi Centers) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4322.SR | Retal Urban Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 4325.SR | Umm Al Qura for Development and Construction Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 6004.SR | CATRION Catering Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 6015.SR | Americana Restaurants International PLC | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 7200.SR | Al Moammar Information Systems Company (MIS) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 7202.SR | Arabian Internet and Communication Services Company (solutions by stc) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 7203.SR | Elm Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 8200.SR | Saudi Reinsurance Company (Saudi Re) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 8230.SR | Al Rajhi Company for Cooperative Insurance (Al Rajhi Takaful) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| 8313.SR | Rasan Information Technology Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-09 |
| A | Agilent Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ACGL | Arch Capital Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ACN | Accenture | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ADM | Archer Daniels Midland | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AEE | Ameren | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AES | AES Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AFL | Aflac | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AIG | American International Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AIZ | Assurant | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AJG | Arthur J. Gallagher & Co. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AKAM | Akamai Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ALB | Albemarle Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ALGN | Align Technology | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ALL | Allstate | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ALLE | Allegion | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AMCR | Amcor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AME | Ametek | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AMP | Ameriprise Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AMT | American Tower | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ANET | Arista Networks | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AON | Aon plc | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AOS | A. O. Smith | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| APA | APA Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| APD | Air Products | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| APH | Amphenol | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| APO | Apollo Global Management | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| APTV | Aptiv | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ARE | Alexandria Real Estate Equities | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ARES | Ares Management | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ATO | Atmos Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AVB | AvalonBay Communities | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AVY | Avery Dennison | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AWK | American Water Works | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| AZO | AutoZone | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BALL | Ball Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BAX | Baxter International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BBY | Best Buy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BDX | Becton Dickinson | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BEN | Franklin Resources | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BF-B | Brown–Forman | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BG | Bunge Global | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BIIB | Biogen | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BLDR | Builders FirstSource | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BMY | Bristol Myers Squibb | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BNY | BNY Mellon | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BR | Broadridge Financial Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BRK-B | Berkshire Hathaway | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BRO | Brown & Brown | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BSX | Boston Scientific | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BX | Blackstone Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| BXP | BXP, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CAH | Cardinal Health | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CARR | Carrier Global | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CASY | Casey's | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CB | Chubb Limited | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CBOE | Cboe Global Markets | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CBRE | CBRE Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CCI | Crown Castle | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CCL | Carnival Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CDW | CDW Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CF | CF Industries | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CFG | Citizens Financial Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CHD | Church & Dwight | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CHRW | C.H. Robinson | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CHTR | Charter Communications | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CI | Cigna | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CIEN | Ciena | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CINF | Cincinnati Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CL | Colgate-Palmolive | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CLX | Clorox | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CME | CME Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CMG | Chipotle Mexican Grill | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CMI | Cummins | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CMS | CMS Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CNC | Centene Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CNP | CenterPoint Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| COF | Capital One | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| COHR | Coherent Corp. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| COIN | Coinbase | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| COO | Cooper Companies (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| COR | Cencora | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CPAY | Corpay | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CPT | Camden Property Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CRH | CRH plc | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CRL | Charles River Laboratories | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CSGP | CoStar Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CTSH | Cognizant | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CTVA | Corteva | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CVNA | Carvana | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| CVS | CVS Health | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| D | Dominion Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DAL | Delta Air Lines | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DD | DuPont | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DE | Deere & Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DECK | Deckers Brands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DELL | Dell Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DG | Dollar General | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DGX | Quest Diagnostics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DHI | D. R. Horton | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DLR | Digital Realty | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DLTR | Dollar Tree | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DOC | Healthpeak Properties | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DOV | Dover Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DOW | Dow Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DPZ | Domino's | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DRI | Darden Restaurants | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DTE | DTE Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DUK | Duke Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DVA | DaVita | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| DVN | Devon Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EBAY | eBay Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ECHO | EchoStar | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ECL | Ecolab | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ED | Consolidated Edison | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EFX | Equifax | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EG | Everest Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EIX | Edison International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EL | Estée Lauder Companies (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ELV | Elevance Health | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EME | Emcor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EMR | Emerson Electric | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EOG | EOG Resources | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EQIX | Equinix | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EQR | Equity Residential | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EQT | EQT Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ERIE | Erie Indemnity | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ES | Eversource Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ESS | Essex Property Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ETN | Eaton Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ETR | Entergy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EVRG | Evergy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EW | Edwards Lifesciences | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EXE | Expand Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EXPD | Expeditors International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EXPE | Expedia Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| EXR | Extra Space Storage | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| F | Ford Motor Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FCX | Freeport-McMoRan | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FDS | FactSet | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FDX | FedEx | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FDXF | FedEx Freight | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FE | FirstEnergy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FFIV | F5, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FICO | Fair Isaac | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FIS | Fidelity National Information Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FISV | Fiserv | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FITB | Fifth Third Bancorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FIX | Comfort Systems USA | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FLEX | Flex Ltd. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FOX | Fox Corporation (Class B) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FOXA | Fox Corporation (Class A) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FRT | Federal Realty Investment Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FSLR | First Solar | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| FTV | Fortive | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GD | General Dynamics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GDDY | GoDaddy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GEN | Gen Digital | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GEV | GE Vernova | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GIS | General Mills | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GL | Globe Life | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GLW | Corning Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GM | General Motors | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GNRC | Generac | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GPC | Genuine Parts Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GPN | Global Payments | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GRMN | Garmin | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| GWW | W. W. Grainger | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HAL | Halliburton | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HAS | Hasbro | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HBAN | Huntington Bancshares | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HCA | HCA Healthcare | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HIG | Hartford (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HII | Huntington Ingalls Industries | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HLT | Hilton Worldwide | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HONA | Honeywell Aerospace | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HOOD | Robinhood Markets | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HPE | Hewlett Packard Enterprise | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HPQ | HP Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HRL | Hormel Foods | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HSIC | Henry Schein | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HST | Host Hotels & Resorts | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HSY | Hershey Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HUBB | Hubbell Incorporated | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HUM | Humana | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| HWM | Howmet Aerospace | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IBKR | Interactive Brokers | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ICE | Intercontinental Exchange | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IEX | IDEX Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IFF | International Flavors & Fragrances | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| INCY | Incyte | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| INVH | Invitation Homes | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IP | International Paper | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IQV | IQVIA | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IR | Ingersoll Rand | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IRM | Iron Mountain | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IT | Gartner | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ITW | Illinois Tool Works | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| IVZ | Invesco | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| J | Jacobs Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| JBHT | J.B. Hunt | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| JBL | Jabil | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| JCI | Johnson Controls | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| JKHY | Jack Henry & Associates | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KEY | KeyCorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KEYS | Keysight Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KIM | Kimco Realty | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KKR | KKR & Co. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KMB | Kimberly-Clark | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KMI | Kinder Morgan | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KR | Kroger | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| KVUE | Kenvue | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| L | Loews Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LDOS | Leidos | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LEN | Lennar | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LH | Labcorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LHX | L3Harris | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LII | Lennox International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LNT | Alliant Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LOW | Lowe's | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LULU | Lululemon Athletica | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LUV | Southwest Airlines | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LVS | Las Vegas Sands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LYB | LyondellBasell | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| LYV | Live Nation Entertainment | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MAA | Mid-America Apartment Communities | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MAS | Masco | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MCK | McKesson Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MCO | Moody's Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MDT | Medtronic | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MET | MetLife | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MGM | MGM Resorts | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MKC | McCormick & Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MLM | Martin Marietta Materials | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MMM | 3M | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MO | Altria | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MOS | Mosaic Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MPC | Marathon Petroleum | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MRNA | Moderna | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MRSH | Marsh McLennan | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MSCI | MSCI Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MSI | Motorola Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MTB | M&T Bank | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| MTD | Mettler Toledo | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NCLH | Norwegian Cruise Line Holdings | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NDAQ | Nasdaq, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NDSN | Nordson Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NEE | NextEra Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NEM | Newmont | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NI | NiSource | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NOC | Northrop Grumman | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NRG | NRG Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NSC | Norfolk Southern | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NTAP | NetApp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NTRS | Northern Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NUE | Nucor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NVR | NVR, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NWS | News Corp (Class B) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| NWSA | News Corp (Class A) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| O | Realty Income | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| OKE | Oneok | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| OMC | Omnicom Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ON | ON Semiconductor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| OTIS | Otis Worldwide | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| OXY | Occidental Petroleum | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PCG | PG&E Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PEG | Public Service Enterprise Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PFG | Principal Financial Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PGR | Progressive Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PH | Parker Hannifin | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PHM | PulteGroup | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PKG | Packaging Corporation of America | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PLD | Prologis | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PM | Philip Morris International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PNC | PNC Financial Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PNR | Pentair | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PNW | Pinnacle West Capital | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PODD | Insulet Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PPG | PPG Industries | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PPL | PPL Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PRU | Prudential Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PSA | Public Storage | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PSKY | Paramount Skydance Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PSX | Phillips 66 | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PTC | PTC Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| PWR | Quanta Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| Q | Qnity Electronics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RCL | Royal Caribbean Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| REG | Regency Centers | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RF | Regions Financial Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RJF | Raymond James Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RL | Ralph Lauren Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RMD | ResMed | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ROK | Rockwell Automation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ROL | Rollins, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RSG | Republic Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| RVTY | Revvity | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SBAC | SBA Communications | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SHW | Sherwin-Williams | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SJM | J.M. Smucker Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SLB | Schlumberger | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SMCI | Supermicro | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SNA | Snap-on | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SO | Southern Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SOLV | Solventum | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SPG | Simon Property Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SPGI | S&P Global | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SRE | Sempra | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| STE | Steris | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| STLD | Steel Dynamics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| STT | State Street Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| STZ | Constellation Brands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SW | Smurfit Westrock | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SWK | Stanley Black & Decker | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SWKS | Skyworks Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SYF | Synchrony Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SYK | Stryker Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| SYY | Sysco | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| T | AT&T | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TAP | Molson Coors Beverage Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TDG | TransDigm Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TDY | Teledyne Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TECH | Bio-Techne | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TEL | TE Connectivity | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TFC | Truist Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TGT | Target Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TJX | TJX Companies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TKO | TKO Group Holdings | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TPL | Texas Pacific Land Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TPR | Tapestry, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TRGP | Targa Resources | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TRMB | Trimble Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TROW | T. Rowe Price | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TRV | Travelers Companies (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TSCO | Tractor Supply | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TSN | Tyson Foods | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TT | Trane Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TTD | Trade Desk (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TXT | Textron | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| TYL | Tyler Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| UAL | United Airlines Holdings | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| UBER | Uber | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| UDR | UDR, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| UHS | Universal Health Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ULTA | Ulta Beauty | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| UNP | Union Pacific Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| URI | United Rentals | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| USB | U.S. Bancorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VEEV | Veeva Systems | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VICI | Vici Properties | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VLO | Valero Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VLTO | Veralto | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VMC | Vulcan Materials Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VRSK | Verisk Analytics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VRSN | Verisign | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VRT | Vertiv | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VST | Vistra Corp. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VTR | Ventas | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VTRS | Viatris | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| VZ | Verizon | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WAB | Wabtec | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WAT | Waters Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WEC | WEC Energy Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WELL | Welltower | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WM | Waste Management | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WMB | Williams Companies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WRB | W. R. Berkley Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WSM | Williams-Sonoma, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WST | West Pharmaceutical Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WTW | Willis Towers Watson | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WY | Weyerhaeuser | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| WYNN | Wynn Resorts | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| XYL | Xylem Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| XYZ | Block, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| YUM | Yum! Brands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ZBH | Zimmer Biomet | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ZBRA | Zebra Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ZTS | Zoetis | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-09 |
| ABNB | Airbnb (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ADP | Automatic Data Processing (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ADSK | Autodesk (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| AEP | American Electric Power (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ALAB | Astera Labs | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ALNY | Alnylam Pharmaceuticals | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| APP | AppLovin (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ARM | Arm Holdings | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ASML | ASML Holding | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| AXON | Axon Enterprise (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| BKNG | Booking Holdings (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| BKR | Baker Hughes (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CCEP | Coca-Cola Europacific Partners | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CEG | Constellation Energy (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CMCSA | Comcast (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CPRT | Copart (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CRWD | CrowdStrike (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CRWV | CoreWeave | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CSX | CSX Corporation (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| CTAS | Cintas (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| DASH | DoorDash (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| DDOG | Datadog (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| DXCM | DexCom (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| EA | Electronic Arts (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| EXC | Exelon (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| FANG | Diamondback Energy (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| FAST | Fastenal (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| FER | Ferrovial | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| FTNT | Fortinet (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| GEHC | GE HealthCare (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| GILD | Gilead Sciences (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| GOOG | Alphabet Inc. (Class C) (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| IDXX | Idexx Laboratories (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ISRG | Intuitive Surgical (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| KDP | Keurig Dr Pepper (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| KHC | Kraft Heinz (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| LIN | Linde plc (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| LITE | Lumentum (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MAR | Marriott International (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MCHP | Microchip Technology (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MDLZ | Mondelez International (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MELI | Mercado Libre | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MNST | Monster Beverage (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MPWR | Monolithic Power Systems (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MRVL | Marvell Technology (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| MSTR | MicroStrategy | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| NBIS | Nebius Group | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| NXPI | NXP Semiconductors (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ODFL | Old Dominion Freight Line (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ORLY | O'Reilly Automotive (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| PAYX | Paychex (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| PCAR | Paccar (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| PDD | PDD Holdings | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| PLTR | Palantir Technologies (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| PYPL | PayPal (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| REGN | Regeneron Pharmaceuticals (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| RKLB | Rocket Lab | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ROP | Roper Technologies (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| ROST | Ross Stores (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| SHOP | Shopify | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| SNDK | Sandisk (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| STX | Seagate Technology (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| TER | Teradyne (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| TMUS | T-Mobile US (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| TRI | Thomson Reuters | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| TTWO | Take-Two Interactive (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| VRTX | Vertex Pharmaceuticals (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| WBD | Warner Bros. Discovery (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| WDAY | Workday, Inc. (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| WDC | Western Digital (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| XEL | Xcel Energy (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-09 |
| AA | Alcoa | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AAL | American Airlines Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AAON | AAON | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ACI | Albertsons | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ACM | AECOM | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ADC | Agree Realty | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AEIS | Advanced Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AFG | American Financial Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AGCO | AGCO | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AHR | American Healthcare REIT | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AIT | Applied Industrial Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ALGM | Allegro MicroSystems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ALK | Alaska Air Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ALLY | Ally Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ALV | Autoliv | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AM | Antero Midstream | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AMG | Affiliated Managers Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AMH | American Homes 4 Rent | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AMKR | Amkor Technology | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AN | AutoNation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ANF | Abercrombie & Fitch | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| APG | APi Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| APPF | AppFolio | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AR | Antero Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ARMK | Aramark | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ARW | Arrow Electronics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ARWR | Arrowhead Pharmaceuticals | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ASB | Associated Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ASH | Ashland Global | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ATI | ATI Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ATR | AptarGroup | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AVAV | AeroVironment | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AVNT | Avient | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AVT | Avnet | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AVTR | Avantor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AXTA | Axalta | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| AYI | Acuity Brands | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BAH | Booz Allen Hamilton | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BBWI | Bath & Body Works, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BC | Brunswick | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BCO | Brink's | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BDC | Belden Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BHF | Brighthouse Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BILL | Bill Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BIO | Bio-Rad Laboratories | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BJ | BJ's Wholesale Club | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BKH | Black Hills Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BLD | TopBuild Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BMRN | BioMarin Pharmaceutical | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BRKR | Bruker | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BROS | Dutch Bros Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BRX | Brixmor Property Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BSY | Bentley Systems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BURL | Burlington Stores | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BWA | BorgWarner | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BWXT | BWX Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| BYD | Boyd Gaming | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CACI | CACI International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CAR | Avis Budget Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CART | Maplebear Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CAVA | Cava Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CBSH | Commerce Bancshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CBT | Cabot Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CCK | Crown Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CDE | Coeur Mining | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CDP | COPT Defense Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CELH | Celsius Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CFR | Frost Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CG | Carlyle Group (The) | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CGNX | Cognex | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CHDN | Churchill Downs Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CHE | Chemed Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CHH | Choice Hotels | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CHRD | Chord Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CHWY | Chewy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CLF | Cleveland-Cliffs | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CLH | Clean Harbors | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CMC | Commercial Metals | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CNH | CNH Industrial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CNM | Core & Main | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CNO | CNO Financial Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CNX | CNX Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| COKE | Coca-Cola Consolidated | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| COLB | Columbia Banking System | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| COLM | Columbia Sportswear | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CPRI | Capri Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CR | Crane | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CRBG | Corebridge Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CROX | Crocs | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CRS | Carpenter Technology | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CRUS | Cirrus Logic | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CSL | Carlisle Companies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CTRE | CareTrust REIT | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CUBE | CubeSmart | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CUZ | Cousins Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CVLT | CommVault Systems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CW | Curtiss-Wright | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CXT | Crane NXT | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| CYTK | Cytokinetics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DAR | Darling Ingredients | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DBX | Dropbox | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DCI | Donaldson Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DINO | HF Sinclair | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DKS | Dick's Sporting Goods | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DLB | Dolby | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DOCN | DigitalOcean | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DOCS | Doximity | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DOCU | Docusign | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DT | Dynatrace | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DTM | DT Midstream | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DUOL | Duolingo | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| DY | Dycom Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EEFT | Euronet Worldwide | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EGP | EastGroup Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EHC | Encompass Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ELAN | Elanco | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ELF | e.l.f. Beauty | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ELS | Equity Lifestyle Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ENS | EnerSys | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ENSG | Ensign Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ENTG | Entegris | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EPR | EPR Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EQH | Equitable Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ESAB | ESAB | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ESNT | Essent Group Ltd. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EVR | Evercore | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EWBC | East West Bancorp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EXEL | Exelixis | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EXLS | EXL Service | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EXP | Eagle Materials | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| EXPO | Exponent, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FAF | First American Financial Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FBIN | Fortune Brands Innovations | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FCFS | FirstCash | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FCN | FTI Consulting | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FFIN | First Financial Bankshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FHI | Federated Hermes | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FHN | First Horizon | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FIVE | Five Below | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FLG | Flagstar Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FLR | Fluor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FLS | Flowserve | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FN | Fabrinet | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FNB | FNB Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FND | Floor & Decor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FNF | Fidelity National Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FOUR | Shift4 | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FR | First Industrial Realty Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| FTI | TechnipFMC | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| G | Genpact | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GAP | Gap Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GATX | GATX | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GBCI | Glacier Bancorp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GEF | Greif, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GGG | Graco Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GHC | Graham Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GLPI | Gaming and Leisure Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GME | GameStop | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GMED | Globus Medical | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GNTX | Gentex | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GPK | Graphic Packaging | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GT | Goodyear Tire & Rubber | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GTLS | Chart Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GWRE | Guidewire Software | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| GXO | GXO Logistics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| H | Hyatt | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HAE | Haemonetics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HALO | Halozyme | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HGV | Hilton Grand Vacations | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HIMS | Hims & Hers Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HL | Hecla Mining | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HLI | Houlihan Lokey | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HLNE | Hamilton Lane | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HOG | Harley-Davidson | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HOMB | Home BancShares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HQY | HealthEquity | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HR | Healthcare Realty Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HRB | H&R Block | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HWC | Hancock Whitney | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| HXL | Hexcel | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| IBOC | Intl Bancshares Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| IDA | Idacorp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| IDCC | InterDigital | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ILMN | Illumina, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| INGR | Ingredion | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| IPGP | IPG Photonics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| IRT | IRT Living | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ITT | ITT Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| JAZZ | Jazz Pharmaceuticals | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| JEF | Jefferies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| JHG | Janus Henderson | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| JLL | Jones Lang LaSalle | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KBH | KB Home | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KBR | KBR, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KD | Kyndryl | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KEX | Kirby Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KNF | Knife River Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KNSL | Kinsale Capital Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KNX | Knight-Swift | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KRC | Kilroy Realty Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KRG | Kite Realty Group Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| KTOS | Kratos Defense & Security Solutions | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LAD | Lithia Motors | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LAMR | Lamar Advertising Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LEA | Lear | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LECO | Lincoln Electric | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LFUS | Littelfuse | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LIVN | LivaNova | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LNTH | Lantheus Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LOPE | Grand Canyon Education | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LPX | Louisiana-Pacific | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LSCC | Lattice Semiconductor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| LSTR | Landstar System | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| M | Macy's | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MANH | Manhattan Associates | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MAT | Mattel | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MEDP | Medpace | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MIDD | Middleby | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MKSI | MKS Instruments | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MLI | Mueller Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MMS | Maximus Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MOG-A | Moog Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MORN | Morningstar, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MP | MP Materials | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MSA | MSA Safety | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MSM | MSC Industrial Direct | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MTDR | Matador Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MTG | MGIC Investment Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MTN | Vail Resorts | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MTSI | MACOM Technology Solutions | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MTZ | MasTec | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MUR | Murphy Oil | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MUSA | Murphy USA | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| MZTI | The Marzetti Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NBIX | Neurocrine Biosciences | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NEU | NewMarket Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NFG | National Fuel Gas | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NJR | New Jersey Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NLY | Annaly Capital Management | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NNN | NNN Reit | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NOV | NOV Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NOVT | Novanta | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NSA | National Storage Affiliates Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NTNX | Nutanix | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NVST | Envista Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NVT | nVent Electric plc | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NWE | NorthWestern Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NXST | Nexstar Media Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NXT | Nextpower | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| NYT | New York Times Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OC | Owens Corning | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OGE | OGE Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OGS | One Gas | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OHI | Omega Healthcare Investors | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OKTA | Okta, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OLED | Universal Display | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OLLI | Ollie's Bargain Outlet | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OLN | Olin Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ONB | Old National Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ONTO | Onto Innovation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OPCH | Option Care Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ORA | Ormat Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| ORI | Old Republic International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OSK | Oshkosh | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OVV | Ovintiv | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| OZK | Bank OZK | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| P | Everpure | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PAG | Penske Automotive Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PATH | UiPath | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PB | Prosperity Bancshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PBF | PBF Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PCTY | Paylocity | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PEGA | Pegasystems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PEN | Penumbra, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PFGC | Performance Food Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PII | Polaris | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PINS | Pinterest | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PK | Park Hotels & Resorts | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PLNT | Planet Fitness | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PNFP | Pinnacle Financial Partners | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| POR | Portland General Electric | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| POST | Post Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PPC | Pilgrim's Pride | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PR | Permian Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PRI | Primerica | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PSN | Parsons Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| PVH | PVH Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| QLYS | Qualys | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| R | Ryder | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| RBA | RB Global | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| RBC | RBC Bearings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| REXR | Rexford Industrial Realty | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| RGA | Reinsurance Group of America | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
| RGEN | Repligen | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-09 |
