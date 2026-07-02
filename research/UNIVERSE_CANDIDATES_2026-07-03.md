# StockSage Candidate Equity Universe — 2026-07-03

**As-of:** 2026-07-03  
**Reconciled by:** universe-reconcile pass (dedupe by Yahoo symbol, case-insensitive)  

## Provenance — one line per source group

- **S&P 500** — 503 rows — source: https://en.wikipedia.org/wiki/List_of_S%26P_500_companies (as-of 2026-07-03)
- **Nasdaq-100** — 101 rows — source: https://en.wikipedia.org/wiki/Nasdaq-100 (as-of 2026-07-03) — 100 companies, 101 tickers (GOOGL+GOOG dual-listed)
- **S&P MidCap 400 (surplus)** — 400 rows — source: https://en.wikipedia.org/wiki/List_of_S%26P_400_companies (as-of 2026-07-03) — MOG.A -> MOG-A Yahoo class-share mapping
- **Tadawul (Saudi, PRIORITY)** — 100 rows — source: https://stockanalysis.com/list/saudi-stock-exchange/ (as-of 2026-07-03) — honest-partial: ~100 largest/most-liquid of 382 Saudi stocks (shortfall ~282 by design)
- **FTSE 100** — 100 rows — source: https://en.wikipedia.org/wiki/FTSE_100_Index (as-of 2026-07-03) — 3 rows suffixVerified=false (CCEP.L, MTLN.L, SDLF.L); BT.A -> BT-A.L
- **DAX 40** — 40 rows — source: https://en.wikipedia.org/wiki/DAX (as-of 2026-07-03) — Airbus mapped to AIR.PA home listing
- **EURO STOXX 50** — 50 rows — source: https://en.wikipedia.org/wiki/EURO_STOXX_50 (as-of 2026-07-03) — 1 row suffixVerified=false (VOW.DE ordinary vs VOW3.DE pref)
- **Nikkei 225** — 223 rows — source: https://en.wikipedia.org/wiki/Nikkei_225 (as-of 2026-07-03) — shortfall ~2 vs nominal 225; 2 rows suffixVerified=false (543A, 285A alphanumeric TSE codes)

_Intermediate scratch file `o2/parsed.json` (400 raw ticker/name pairs) was the S&P 400 agent's pre-mapping artifact — 399/400 identical to the finalized `sp400.json`, differing only on the raw `MOG.A` vs Yahoo-mapped `MOG-A`. It lacks the exchange/group/suffixVerified schema and is EXCLUDED as a duplicate intermediate; the finalized `sp400.json` is used. No rows lost._

> **CANDIDATE POOL — every symbol must be verified through the app Yahoo-v8 fetch path before inclusion; `suffixVerified=false` rows are inferred, not confirmed; sourced live, never from model memory.**

Ordering: Saudi (.SR) names FIRST (2222.SR / Saudi Aramco leads), then grouped by index. A symbol present in multiple indices is listed once under its most-specific/liquid group; secondary memberships are noted in the Name column.

| Yahoo symbol | Name | Exchange | Market group | suffixVerified | source URL | as-of |
|---|---|---|---|---|---|---|
| 2222.SR | Saudi Arabian Oil Company (Aramco) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1010.SR | Riyad Bank | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1020.SR | Bank Aljazira | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1030.SR | The Saudi Investment Bank | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1050.SR | Banque Saudi Fransi | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1060.SR | Saudi Awwal Bank (SAB) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1080.SR | Arab National Bank | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1111.SR | Saudi Tadawul Group Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1120.SR | Al Rajhi Banking and Investment Corporation | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1140.SR | Bank Albilad | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1150.SR | Alinma Bank | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1180.SR | The Saudi National Bank | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1211.SR | Saudi Arabian Mining Company (Maaden) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1212.SR | Astra Industrial Group Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1303.SR | Electrical Industries Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1321.SR | East Pipes Integrated Company for Industry | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1322.SR | Al Masane Al Kobra Mining Company (AMAK) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1810.SR | Seera Holding Group | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 1830.SR | Leejam Sports Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2010.SR | Saudi Basic Industries Corporation (SABIC) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2020.SR | SABIC Agri-Nutrients Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2050.SR | Savola Group Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2060.SR | National Industrialization Company (Tasnee) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2070.SR | Saudi Pharmaceutical Industries and Medical Appliances Corporation (SPIMACO) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2080.SR | National Gas and Industrialization Company (GASCO) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2081.SR | Alkhorayef Water and Power Technologies Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2082.SR | ACWA Power Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2083.SR | Power and Water Utility Company for Jubail and Yanbu (Marafiq) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2223.SR | Saudi Aramco Base Oil Company - Luberef | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2230.SR | Saudi Chemical Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2250.SR | Saudi Industrial Investment Group | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2270.SR | Saudia Dairy & Foodstuff Company (SADAFCO) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2280.SR | Almarai Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2290.SR | Yanbu National Petrochemical Company (Yansab) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2310.SR | Sahara International Petrochemical Company (Sipchem) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2320.SR | Al-Babtain Power and Telecommunications Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2330.SR | Advanced Petrochemical Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2350.SR | Saudi Kayan Petrochemical Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2380.SR | Rabigh Refining and Petrochemical Company (Petro Rabigh) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2381.SR | Arabian Drilling Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 2382.SR | ADES Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 3020.SR | YAMAMA Cement Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 3030.SR | Saudi Cement Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 3040.SR | Qassim Cement Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4001.SR | Abdullah Al-Othaim Markets Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4002.SR | Mouwasat Medical Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4003.SR | United Electronics Company (eXtra) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4004.SR | Dallah Healthcare Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4005.SR | National Medical Care Company (Care) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4007.SR | Al Hammadi Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4013.SR | Dr. Sulaiman Al Habib Medical Services Group Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4015.SR | Jamjoom Pharmaceuticals Factory Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4017.SR | Dr. Soliman Abdel Kader Fakeeh Hospital Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4018.SR | Almoosa Health Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4019.SR | Specialized Medical Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4020.SR | Saudi Real Estate Company (Al Akaria) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4030.SR | The National Shipping Company of Saudi Arabia (Bahri) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4031.SR | Saudi Ground Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4071.SR | Arabian Contracting Services Company (Al Arabia) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4072.SR | MBC Group | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4084.SR | Derayah Financial Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4090.SR | Taiba Investment Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4100.SR | Makkah Construction and Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4142.SR | Riyadh Cables Group Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4150.SR | Arriyadh Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4161.SR | BinDawood Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4162.SR | Almunajem Foods Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4163.SR | Al-Dawaa Medical Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4164.SR | Nahdi Medical Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4165.SR | Al Majed for Oud Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4190.SR | Jarir Marketing Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4200.SR | Aldrees Petroleum and Transport Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4210.SR | Saudi Research and Media Group (SRMG) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4220.SR | Emaar The Economic City | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4250.SR | Jabal Omar Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4260.SR | United International Transportation Company (Budget Saudi) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4263.SR | SAL Saudi Logistics Services Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4264.SR | Flynas Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4280.SR | Kingdom Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4291.SR | National Company for Learning and Education | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4300.SR | Dar Al Arkan Real Estate Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4310.SR | Knowledge Economic City Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4321.SR | Arabian Centres Company (Cenomi Centers) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4322.SR | Retal Urban Development Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 4325.SR | Umm Al Qura for Development and Construction Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 5110.SR | Saudi Electricity Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 6004.SR | CATRION Catering Holding Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 6010.SR | The National Agricultural Development Company (NADEC) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 6015.SR | Americana Restaurants International PLC | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 7010.SR | Saudi Telecom Company (STC) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 7020.SR | Etihad Etisalat Company (Mobily) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 7030.SR | Mobile Telecommunications Company Saudi Arabia (Zain KSA) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 7200.SR | Al Moammar Information Systems Company (MIS) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 7202.SR | Arabian Internet and Communication Services Company (solutions by stc) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 7203.SR | Elm Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 8010.SR | The Company for Cooperative Insurance (Tawuniya) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 8200.SR | Saudi Reinsurance Company (Saudi Re) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 8210.SR | Bupa Arabia for Cooperative Insurance Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 8230.SR | Al Rajhi Company for Cooperative Insurance (Al Rajhi Takaful) | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| 8313.SR | Rasan Information Technology Company | Tadawul | Tadawul (Saudi, PRIORITY) | true | https://stockanalysis.com/list/saudi-stock-exchange/ | 2026-07-03 |
| A | Agilent Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ABBV | AbbVie | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ABT | Abbott Laboratories | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ACGL | Arch Capital Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ACN | Accenture | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ADM | Archer Daniels Midland | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AEE | Ameren | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AES | AES Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AFL | Aflac | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AIG | American International Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AIZ | Assurant | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AJG | Arthur J. Gallagher & Co. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AKAM | Akamai Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ALB | Albemarle Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ALGN | Align Technology | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ALL | Allstate | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ALLE | Allegion | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AMCR | Amcor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AME | Ametek | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AMP | Ameriprise Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AMT | American Tower | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ANET | Arista Networks | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AON | Aon plc | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AOS | A. O. Smith | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| APA | APA Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| APD | Air Products | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| APH | Amphenol | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| APO | Apollo Global Management | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| APTV | Aptiv | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ARE | Alexandria Real Estate Equities | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ARES | Ares Management | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ATO | Atmos Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AVB | AvalonBay Communities | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AVY | Avery Dennison | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AWK | American Water Works | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AXP | American Express | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AZO | AutoZone | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BA | Boeing | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BAC | Bank of America | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BALL | Ball Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BAX | Baxter International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BBY | Best Buy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BDX | Becton Dickinson | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BEN | Franklin Resources | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BF-B | Brown–Forman | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BG | Bunge Global | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BIIB | Biogen | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BLDR | Builders FirstSource | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BLK | BlackRock | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BMY | Bristol Myers Squibb | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BNY | BNY Mellon | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BR | Broadridge Financial Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BRK-B | Berkshire Hathaway | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BRO | Brown & Brown | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BSX | Boston Scientific | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BX | Blackstone Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| BXP | BXP, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| C | Citigroup | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CAH | Cardinal Health | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CARR | Carrier Global | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CASY | Casey's | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CAT | Caterpillar Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CB | Chubb Limited | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CBOE | Cboe Global Markets | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CBRE | CBRE Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CCI | Crown Castle | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CCL | Carnival Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CDW | CDW Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CF | CF Industries | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CFG | Citizens Financial Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CHD | Church & Dwight | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CHRW | C.H. Robinson | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CHTR | Charter Communications | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CI | Cigna | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CIEN | Ciena | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CINF | Cincinnati Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CL | Colgate-Palmolive | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CLX | Clorox | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CME | CME Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CMG | Chipotle Mexican Grill | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CMI | Cummins | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CMS | CMS Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CNC | Centene Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CNP | CenterPoint Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| COF | Capital One | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| COHR | Coherent Corp. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| COIN | Coinbase | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| COO | Cooper Companies (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| COP | ConocoPhillips | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| COR | Cencora | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CPAY | Corpay | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CPT | Camden Property Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CRH | CRH plc | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CRL | Charles River Laboratories | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CRM | Salesforce | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CSGP | CoStar Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CTSH | Cognizant | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CTVA | Corteva | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CVNA | Carvana | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CVS | CVS Health | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| CVX | Chevron Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| D | Dominion Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DAL | Delta Air Lines | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DD | DuPont | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DE | Deere & Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DECK | Deckers Brands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DELL | Dell Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DG | Dollar General | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DGX | Quest Diagnostics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DHI | D. R. Horton | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DHR | Danaher Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DIS | Walt Disney Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DLR | Digital Realty | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DLTR | Dollar Tree | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DOC | Healthpeak Properties | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DOV | Dover Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DOW | Dow Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DPZ | Domino's | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DRI | Darden Restaurants | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DTE | DTE Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DUK | Duke Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DVA | DaVita | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| DVN | Devon Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EBAY | eBay Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ECHO | EchoStar | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ECL | Ecolab | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ED | Consolidated Edison | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EFX | Equifax | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EG | Everest Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EIX | Edison International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EL | Estée Lauder Companies (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ELV | Elevance Health | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EME | Emcor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EMR | Emerson Electric | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EOG | EOG Resources | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EQIX | Equinix | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EQR | Equity Residential | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EQT | EQT Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ERIE | Erie Indemnity | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ES | Eversource Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ESS | Essex Property Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ETN | Eaton Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ETR | Entergy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EVRG | Evergy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EW | Edwards Lifesciences | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EXE | Expand Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EXPD | Expeditors International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EXPE | Expedia Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| EXR | Extra Space Storage | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| F | Ford Motor Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FCX | Freeport-McMoRan | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FDS | FactSet | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FDX | FedEx | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FDXF | FedEx Freight | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FE | FirstEnergy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FFIV | F5, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FICO | Fair Isaac | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FIS | Fidelity National Information Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FISV | Fiserv | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FITB | Fifth Third Bancorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FIX | Comfort Systems USA | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FLEX | Flex Ltd. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FOX | Fox Corporation (Class B) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FOXA | Fox Corporation (Class A) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FRT | Federal Realty Investment Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FSLR | First Solar | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| FTV | Fortive | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GD | General Dynamics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GDDY | GoDaddy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GE | GE Aerospace | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GEN | Gen Digital | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GEV | GE Vernova | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GIS | General Mills | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GL | Globe Life | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GLW | Corning Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GM | General Motors | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GNRC | Generac | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GPC | Genuine Parts Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GPN | Global Payments | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GRMN | Garmin | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GS | Goldman Sachs | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| GWW | W. W. Grainger | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HAL | Halliburton | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HAS | Hasbro | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HBAN | Huntington Bancshares | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HCA | HCA Healthcare | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HD | Home Depot (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HIG | Hartford (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HII | Huntington Ingalls Industries | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HLT | Hilton Worldwide | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HONA | Honeywell Aerospace | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HOOD | Robinhood Markets | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HPE | Hewlett Packard Enterprise | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HPQ | HP Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HRL | Hormel Foods | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HSIC | Henry Schein | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HST | Host Hotels & Resorts | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HSY | Hershey Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HUBB | Hubbell Incorporated | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HUM | Humana | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| HWM | Howmet Aerospace | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IBKR | Interactive Brokers | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IBM | IBM | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ICE | Intercontinental Exchange | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IEX | IDEX Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IFF | International Flavors & Fragrances | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| INCY | Incyte | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| INVH | Invitation Homes | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IP | International Paper | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IQV | IQVIA | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IR | Ingersoll Rand | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IRM | Iron Mountain | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IT | Gartner | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ITW | Illinois Tool Works | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| IVZ | Invesco | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| J | Jacobs Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| JBHT | J.B. Hunt | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| JBL | Jabil | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| JCI | Johnson Controls | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| JKHY | Jack Henry & Associates | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| JNJ | Johnson & Johnson | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| JPM | JPMorgan Chase | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KEY | KeyCorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KEYS | Keysight Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KIM | Kimco Realty | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KKR | KKR & Co. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KMB | Kimberly-Clark | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KMI | Kinder Morgan | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KO | Coca-Cola Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KR | Kroger | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| KVUE | Kenvue | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| L | Loews Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LDOS | Leidos | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LEN | Lennar | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LH | Labcorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LHX | L3Harris | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LII | Lennox International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LLY | Lilly (Eli) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LMT | Lockheed Martin | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LNT | Alliant Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LOW | Lowe's | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LULU | Lululemon Athletica | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LUV | Southwest Airlines | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LVS | Las Vegas Sands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LYB | LyondellBasell | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| LYV | Live Nation Entertainment | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MA | Mastercard | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MAA | Mid-America Apartment Communities | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MAS | Masco | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MCD | McDonald's | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MCK | McKesson Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MCO | Moody's Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MDT | Medtronic | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MET | MetLife | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MGM | MGM Resorts | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MKC | McCormick & Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MLM | Martin Marietta Materials | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MMM | 3M | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MO | Altria | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MOS | Mosaic Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MPC | Marathon Petroleum | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MRK | Merck & Co. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MRNA | Moderna | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MRSH | Marsh McLennan | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MS | Morgan Stanley | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MSCI | MSCI Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MSI | Motorola Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MTB | M&T Bank | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| MTD | Mettler Toledo | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NCLH | Norwegian Cruise Line Holdings | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NDAQ | Nasdaq, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NDSN | Nordson Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NEE | NextEra Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NEM | Newmont | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NI | NiSource | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NKE | Nike, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NOC | Northrop Grumman | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NOW | ServiceNow | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NRG | NRG Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NSC | Norfolk Southern | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NTAP | NetApp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NTRS | Northern Trust | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NUE | Nucor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NVR | NVR, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NWS | News Corp (Class B) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| NWSA | News Corp (Class A) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| O | Realty Income | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| OKE | Oneok | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| OMC | Omnicom Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ON | ON Semiconductor | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ORCL | Oracle Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| OTIS | Otis Worldwide | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| OXY | Occidental Petroleum | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PCG | PG&E Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PEG | Public Service Enterprise Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PFE | Pfizer | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PFG | Principal Financial Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PG | Procter & Gamble | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PGR | Progressive Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PH | Parker Hannifin | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PHM | PulteGroup | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PKG | Packaging Corporation of America | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PLD | Prologis | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PM | Philip Morris International | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PNC | PNC Financial Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PNR | Pentair | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PNW | Pinnacle West Capital | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PODD | Insulet Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PPG | PPG Industries | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PPL | PPL Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PRU | Prudential Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PSA | Public Storage | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PSKY | Paramount Skydance Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PSX | Phillips 66 | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PTC | PTC Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| PWR | Quanta Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| Q | Qnity Electronics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RCL | Royal Caribbean Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| REG | Regency Centers | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RF | Regions Financial Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RJF | Raymond James Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RL | Ralph Lauren Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RMD | ResMed | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ROK | Rockwell Automation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ROL | Rollins, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RSG | Republic Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RTX | RTX Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| RVTY | Revvity | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SBAC | SBA Communications | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SCHW | Charles Schwab Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SHW | Sherwin-Williams | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SJM | J.M. Smucker Company (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SLB | Schlumberger | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SMCI | Supermicro | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SNA | Snap-on | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SO | Southern Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SOLV | Solventum | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SPG | Simon Property Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SPGI | S&P Global | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SRE | Sempra | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| STE | Steris | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| STLD | Steel Dynamics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| STT | State Street Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| STZ | Constellation Brands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SW | Smurfit Westrock | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SWK | Stanley Black & Decker | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SWKS | Skyworks Solutions | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SYF | Synchrony Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SYK | Stryker Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| SYY | Sysco | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| T | AT&T | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TAP | Molson Coors Beverage Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TDG | TransDigm Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TDY | Teledyne Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TECH | Bio-Techne | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TEL | TE Connectivity | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TFC | Truist Financial | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TGT | Target Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TJX | TJX Companies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TKO | TKO Group Holdings | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TMO | Thermo Fisher Scientific | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TPL | Texas Pacific Land Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TPR | Tapestry, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TRGP | Targa Resources | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TRMB | Trimble Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TROW | T. Rowe Price | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TRV | Travelers Companies (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TSCO | Tractor Supply | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TSN | Tyson Foods | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TT | Trane Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TTD | Trade Desk (The) | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TXT | Textron | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| TYL | Tyler Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| UAL | United Airlines Holdings | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| UBER | Uber | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| UDR | UDR, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| UHS | Universal Health Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ULTA | Ulta Beauty | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| UNH | UnitedHealth Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| UNP | Union Pacific Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| UPS | United Parcel Service | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| URI | United Rentals | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| USB | U.S. Bancorp | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| V | Visa Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VEEV | Veeva Systems | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VICI | Vici Properties | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VLO | Valero Energy | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VLTO | Veralto | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VMC | Vulcan Materials Company | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VRSK | Verisk Analytics | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VRSN | Verisign | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VRT | Vertiv | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VST | Vistra Corp. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VTR | Ventas | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VTRS | Viatris | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| VZ | Verizon | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WAB | Wabtec | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WAT | Waters Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WEC | WEC Energy Group | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WELL | Welltower | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WFC | Wells Fargo | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WM | Waste Management | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WMB | Williams Companies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WRB | W. R. Berkley Corporation | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WSM | Williams-Sonoma, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WST | West Pharmaceutical Services | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WTW | Willis Towers Watson | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WY | Weyerhaeuser | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| WYNN | Wynn Resorts | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| XOM | ExxonMobil | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| XYL | Xylem Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| XYZ | Block, Inc. | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| YUM | Yum! Brands | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ZBH | Zimmer Biomet | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ZBRA | Zebra Technologies | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| ZTS | Zoetis | NYSE/Nasdaq | S&P 500 | true | https://en.wikipedia.org/wiki/List_of_S%26P_500_companies | 2026-07-03 |
| AAPL | Apple Inc. (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ABNB | Airbnb (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ADBE | Adobe Inc. (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ADI | Analog Devices (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ADP | Automatic Data Processing (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ADSK | Autodesk (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AEP | American Electric Power (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ALAB | Astera Labs | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ALNY | Alnylam Pharmaceuticals | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AMAT | Applied Materials (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AMD | Advanced Micro Devices (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AMGN | Amgen (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AMZN | Amazon (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| APP | AppLovin (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ARM | Arm Holdings | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ASML | ASML Holding | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AVGO | Broadcom (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AXON | Axon Enterprise (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| BKNG | Booking Holdings (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| BKR | Baker Hughes (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CCEP | Coca-Cola Europacific Partners | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CDNS | Cadence Design Systems (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CEG | Constellation Energy (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CMCSA | Comcast (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| COST | Costco (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CPRT | Copart (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CRWD | CrowdStrike (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CRWV | CoreWeave | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CSCO | Cisco (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CSX | CSX Corporation (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| CTAS | Cintas (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| DASH | DoorDash (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| DDOG | Datadog (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| DXCM | DexCom (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| EA | Electronic Arts (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| EXC | Exelon (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| FANG | Diamondback Energy (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| FAST | Fastenal (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| FER | Ferrovial | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| FTNT | Fortinet (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| GEHC | GE HealthCare (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| GILD | Gilead Sciences (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| GOOG | Alphabet Inc. (Class C) (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| GOOGL | Alphabet Inc. (Class A) (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| HON | Honeywell (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| IDXX | Idexx Laboratories (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| INTC | Intel (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| INTU | Intuit (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ISRG | Intuitive Surgical (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| KDP | Keurig Dr Pepper (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| KHC | Kraft Heinz (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| KLAC | KLA Corporation (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| LIN | Linde plc (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| LITE | Lumentum (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| LRCX | Lam Research (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MAR | Marriott International (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MCHP | Microchip Technology (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MDLZ | Mondelez International (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MELI | Mercado Libre | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| META | Meta Platforms (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MNST | Monster Beverage (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MPWR | Monolithic Power Systems (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MRVL | Marvell Technology (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MSFT | Microsoft (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MSTR | MicroStrategy | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| MU | Micron Technology (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| NBIS | Nebius Group | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| NFLX | Netflix, Inc. (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| NVDA | Nvidia (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| NXPI | NXP Semiconductors (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ODFL | Old Dominion Freight Line (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ORLY | O'Reilly Automotive (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| PANW | Palo Alto Networks (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| PAYX | Paychex (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| PCAR | Paccar (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| PDD | PDD Holdings | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| PEP | PepsiCo (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| PLTR | Palantir Technologies (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| PYPL | PayPal (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| QCOM | Qualcomm (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| REGN | Regeneron Pharmaceuticals (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| RKLB | Rocket Lab | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ROP | Roper Technologies (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| ROST | Ross Stores (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| SBUX | Starbucks (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| SHOP | Shopify | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| SNDK | Sandisk (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| SNPS | Synopsys (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| STX | Seagate Technology (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| TER | Teradyne (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| TMUS | T-Mobile US (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| TRI | Thomson Reuters | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| TSLA | Tesla, Inc. (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| TTWO | Take-Two Interactive (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| TXN | Texas Instruments (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| VRTX | Vertex Pharmaceuticals (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| WBD | Warner Bros. Discovery (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| WDAY | Workday, Inc. (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| WDC | Western Digital (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| WMT | Walmart (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| XEL | Xcel Energy (also: S&P 500) | NASDAQ | Nasdaq-100 | true | https://en.wikipedia.org/wiki/Nasdaq-100 | 2026-07-03 |
| AA | Alcoa | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AAL | American Airlines Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AAON | AAON | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ACI | Albertsons | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ACM | AECOM | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ADC | Agree Realty | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AEIS | Advanced Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AFG | American Financial Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AGCO | AGCO | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AHR | American Healthcare REIT | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AIT | Applied Industrial Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ALGM | Allegro MicroSystems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ALK | Alaska Air Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ALLY | Ally Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ALV | Autoliv | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AM | Antero Midstream | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AMG | Affiliated Managers Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AMH | American Homes 4 Rent | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AMKR | Amkor Technology | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AN | AutoNation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ANF | Abercrombie & Fitch | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| APG | APi Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| APPF | AppFolio | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AR | Antero Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ARMK | Aramark | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ARW | Arrow Electronics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ARWR | Arrowhead Pharmaceuticals | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ASB | Associated Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ASH | Ashland Global | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ATI | ATI Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ATR | AptarGroup | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AVAV | AeroVironment | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AVNT | Avient | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AVT | Avnet | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AVTR | Avantor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AXTA | Axalta | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AYI | Acuity Brands | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BAH | Booz Allen Hamilton | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BBWI | Bath & Body Works, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BC | Brunswick | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BCO | Brink's | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BDC | Belden Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BHF | Brighthouse Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BILL | Bill Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BIO | Bio-Rad Laboratories | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BJ | BJ's Wholesale Club | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BKH | Black Hills Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BLD | TopBuild Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BMRN | BioMarin Pharmaceutical | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BRKR | Bruker | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BROS | Dutch Bros Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BRX | Brixmor Property Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BSY | Bentley Systems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BURL | Burlington Stores | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BWA | BorgWarner | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BWXT | BWX Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| BYD | Boyd Gaming | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CACI | CACI International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CAR | Avis Budget Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CART | Maplebear Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CAVA | Cava Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CBSH | Commerce Bancshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CBT | Cabot Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CCK | Crown Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CDE | Coeur Mining | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CDP | COPT Defense Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CELH | Celsius Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CFR | Frost Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CG | Carlyle Group (The) | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CGNX | Cognex | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CHDN | Churchill Downs Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CHE | Chemed Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CHH | Choice Hotels | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CHRD | Chord Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CHWY | Chewy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CLF | Cleveland-Cliffs | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CLH | Clean Harbors | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CMC | Commercial Metals | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CNH | CNH Industrial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CNM | Core & Main | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CNO | CNO Financial Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CNX | CNX Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| COKE | Coca-Cola Consolidated | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| COLB | Columbia Banking System | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| COLM | Columbia Sportswear | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CPRI | Capri Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CR | Crane | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CRBG | Corebridge Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CROX | Crocs | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CRS | Carpenter Technology | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CRUS | Cirrus Logic | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CSL | Carlisle Companies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CTRE | CareTrust REIT | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CUBE | CubeSmart | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CUZ | Cousins Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CVLT | CommVault Systems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CW | Curtiss-Wright | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CXT | Crane NXT | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| CYTK | Cytokinetics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DAR | Darling Ingredients | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DBX | Dropbox | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DCI | Donaldson Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DINO | HF Sinclair | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DKS | Dick's Sporting Goods | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DLB | Dolby | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DOCN | DigitalOcean | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DOCS | Doximity | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DOCU | Docusign | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DT | Dynatrace | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DTM | DT Midstream | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DUOL | Duolingo | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| DY | Dycom Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EEFT | Euronet Worldwide | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EGP | EastGroup Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EHC | Encompass Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ELAN | Elanco | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ELF | e.l.f. Beauty | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ELS | Equity Lifestyle Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ENS | EnerSys | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ENSG | Ensign Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ENTG | Entegris | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EPR | EPR Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EQH | Equitable Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ESAB | ESAB | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ESNT | Essent Group Ltd. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EVR | Evercore | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EWBC | East West Bancorp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EXEL | Exelixis | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EXLS | EXL Service | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EXP | Eagle Materials | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| EXPO | Exponent, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FAF | First American Financial Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FBIN | Fortune Brands Innovations | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FCFS | FirstCash | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FCN | FTI Consulting | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FFIN | First Financial Bankshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FHI | Federated Hermes | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FHN | First Horizon | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FIVE | Five Below | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FLG | Flagstar Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FLR | Fluor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FLS | Flowserve | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FN | Fabrinet | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FNB | FNB Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FND | Floor & Decor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FNF | Fidelity National Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FOUR | Shift4 | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FR | First Industrial Realty Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| FTI | TechnipFMC | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| G | Genpact | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GAP | Gap Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GATX | GATX | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GBCI | Glacier Bancorp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GEF | Greif, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GGG | Graco Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GHC | Graham Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GLPI | Gaming and Leisure Properties | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GME | GameStop | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GMED | Globus Medical | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GNTX | Gentex | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GPK | Graphic Packaging | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GT | Goodyear Tire & Rubber | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GTLS | Chart Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GWRE | Guidewire Software | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| GXO | GXO Logistics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| H | Hyatt | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HAE | Haemonetics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HALO | Halozyme | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HGV | Hilton Grand Vacations | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HIMS | Hims & Hers Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HL | Hecla Mining | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HLI | Houlihan Lokey | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HLNE | Hamilton Lane | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HOG | Harley-Davidson | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HOMB | Home BancShares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HQY | HealthEquity | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HR | Healthcare Realty Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HRB | H&R Block | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HWC | Hancock Whitney | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| HXL | Hexcel | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| IBOC | Intl Bancshares Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| IDA | Idacorp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| IDCC | InterDigital | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ILMN | Illumina, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| INGR | Ingredion | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| IPGP | IPG Photonics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| IRT | IRT Living | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ITT | ITT Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| JAZZ | Jazz Pharmaceuticals | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| JEF | Jefferies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| JHG | Janus Henderson | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| JLL | Jones Lang LaSalle | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KBH | KB Home | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KBR | KBR, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KD | Kyndryl | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KEX | Kirby Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KNF | Knife River Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KNSL | Kinsale Capital Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KNX | Knight-Swift | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KRC | Kilroy Realty Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KRG | Kite Realty Group Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| KTOS | Kratos Defense & Security Solutions | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LAD | Lithia Motors | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LAMR | Lamar Advertising Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LEA | Lear | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LECO | Lincoln Electric | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LFUS | Littelfuse | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LIVN | LivaNova | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LNTH | Lantheus Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LOPE | Grand Canyon Education | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LPX | Louisiana-Pacific | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LSCC | Lattice Semiconductor | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| LSTR | Landstar System | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| M | Macy's | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MANH | Manhattan Associates | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MAT | Mattel | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MEDP | Medpace | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MIDD | Middleby | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MKSI | MKS Instruments | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MLI | Mueller Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MMS | Maximus Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MOG-A | Moog Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MORN | Morningstar, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MP | MP Materials | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MSA | MSA Safety | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MSM | MSC Industrial Direct | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MTDR | Matador Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MTG | MGIC Investment Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MTN | Vail Resorts | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MTSI | MACOM Technology Solutions | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MTZ | MasTec | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MUR | Murphy Oil | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MUSA | Murphy USA | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| MZTI | The Marzetti Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NBIX | Neurocrine Biosciences | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NEU | NewMarket Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NFG | National Fuel Gas | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NJR | New Jersey Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NLY | Annaly Capital Management | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NNN | NNN Reit | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NOV | NOV Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NOVT | Novanta | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NSA | National Storage Affiliates Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NTNX | Nutanix | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NVST | Envista Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NVT | nVent Electric plc | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NWE | NorthWestern Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NXST | Nexstar Media Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NXT | Nextpower | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| NYT | New York Times Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OC | Owens Corning | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OGE | OGE Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OGS | One Gas | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OHI | Omega Healthcare Investors | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OKTA | Okta, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OLED | Universal Display | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OLLI | Ollie's Bargain Outlet | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OLN | Olin Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ONB | Old National Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ONTO | Onto Innovation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OPCH | Option Care Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ORA | Ormat Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ORI | Old Republic International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OSK | Oshkosh | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OVV | Ovintiv | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| OZK | Bank OZK | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| P | Everpure | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PAG | Penske Automotive Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PATH | UiPath | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PB | Prosperity Bancshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PBF | PBF Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PCTY | Paylocity | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PEGA | Pegasystems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PEN | Penumbra, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PFGC | Performance Food Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PII | Polaris | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PINS | Pinterest | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PK | Park Hotels & Resorts | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PLNT | Planet Fitness | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PNFP | Pinnacle Financial Partners | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| POR | Portland General Electric | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| POST | Post Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PPC | Pilgrim's Pride | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PR | Permian Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PRI | Primerica | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PSN | Parsons Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| PVH | PVH Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| QLYS | Qualys | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| R | Ryder | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RBA | RB Global | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RBC | RBC Bearings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| REXR | Rexford Industrial Realty | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RGA | Reinsurance Group of America | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RGEN | Repligen | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RGLD | Royal Gold | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RH | RH | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RLI | RLI Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RMBS | Rambus | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RNR | RenaissanceRe | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ROIV | Roivant Sciences | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ROKU | Roku, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RPM | RPM International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RRC | Range Resources | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RRX | Regal Rexnord | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RS | Reliance, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RYAN | Ryan Specialty | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| RYN | Rayonier | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SAIA | Saia | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SAIC | Science Applications Intl Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SAM | Boston Beer Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SANM | Sanmina Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SARO | StandardAero | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SBRA | Sabra Health Care REIT | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SCI | Service Corp Intl | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SEIC | SEI Investments Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SF | Stifel | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SFM | Sprouts Farmers Market | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SGI | Somnigroup International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SHC | Sotera Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SIGI | Selective Insurance Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SIRI | SiriusXM | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SITM | SiTime | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SLAB | Silicon Labs | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SLGN | Silgan Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SLM | SLM Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SMG | Scotts Miracle-Gro Company | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SMTC | Semtech | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SN | SharkNinja | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SNX | TD Synnex | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SOLS | Solstice Advanced Materials | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SON | Sonoco | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SPXC | SPX Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SR | Spire | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SSB | South State Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SSD | Simpson Manufacturing | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ST | Sensata Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| STAG | STAG Industrial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| STRL | Sterling Infrastructure | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| STWD | Starwood Property Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SWX | Southwest Gas Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| SYNA | Synaptics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TCBI | Texas Capital Bancshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TEX | Terex | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| THC | Tenet Health | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| THG | Hanover Insurance | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| THO | Thor Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TKR | Timken | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TLN | Talen Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TMHC | Taylor Morrison | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TNL | Travel + Leisure Co. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TOL | Toll Brothers | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TREX | Trex | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TRU | TransUnion | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TTC | Toro | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TTEK | Tetra Tech | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TTMI | TTM Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TWLO | Twilio | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TXNM | TXNM Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| TXRH | Texas Roadhouse | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| UBSI | United Bankshares | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| UFPI | UFP Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| UGI | UGI Corp | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ULS | UL Solutions | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| UMBF | UMB Financial Corp. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| UNM | Unum | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| USFD | US Foods | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| UTHR | United Therapeutics | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VAL | Valaris | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VC | Visteon | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VFC | VF Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VIAV | Viavi Solutions | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VICR | Vicor Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VLY | Valley Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VMI | Valmont Industries | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VNO | Vornado Realty Trust | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VNOM | Viper Energy | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VNT | Vontier | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VOYA | Voya Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| VVV | Valvoline | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WAL | Western Alliance Bancorporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WBS | Webster Bank | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WCC | WESCO International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WEX | WEX Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WFRD | Weatherford International | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WH | Wyndham Hotels & Resorts | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WHR | Whirlpool Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WING | Wingstop | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WLK | Westlake Corporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WMG | Warner Music Group | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WMS | Advanced Drainage Systems | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WPC | W. P. Carey | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WSO | Watsco | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WTFC | Wintrust Financial | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WTRG | Essential Utilities | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WTS | Watts Water Technologies | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| WWD | Woodward, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| XPO | XPO, Inc. | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| XRAY | Dentsply Sirona | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| YETI | Yeti Holdings | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| ZION | Zions Bancorporation | NYSE/Nasdaq (US) | S&P MidCap 400 (surplus) | true | https://en.wikipedia.org/wiki/List_of_S%26P_400_companies | 2026-07-03 |
| AAF.L | Airtel Africa | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| AAL.L | Anglo American plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ABDN.L | Aberdeen Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ABF.L | Associated British Foods | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ADM.L | Admiral Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ALW.L | Alliance Witan | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ANTO.L | Antofagasta plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| AUTO.L | Autotrader Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| AV.L | Aviva | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| AZN.L | AstraZeneca | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BA.L | BAE Systems | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BAB.L | Babcock International | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BARC.L | Barclays | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BATS.L | British American Tobacco | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BBOX.L | Tritax Big Box REIT | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BEZ.L | Beazley | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BGEO.L | Lion Finance Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BLND.L | British Land | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BNZL.L | Bunzl | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BP.L | BP | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BRBY.L | Burberry Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BT-A.L | BT Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| BTRW.L | Barratt Redrow | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| CCC.L | Computacenter | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| CCEP.L | Coca-Cola Europacific Partners | LSE | FTSE 100 | false | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| CCH.L | Coca-Cola HBC | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| CNA.L | Centrica | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| CPG.L | Compass Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| CRDA.L | Croda International | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| CTEC.L | Convatec | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| DCC.L | DCC plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| DGE.L | Diageo | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| DPLM.L | Diploma | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| EDV.L | Endeavour Mining | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ENT.L | Entain | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| EXPN.L | Experian | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| FCIT.L | F & C Investment Trust | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| FRES.L | Fresnillo plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| GAW.L | Games Workshop | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| GLEN.L | Glencore | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| GSK.L | GSK plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| HLMA.L | Halma plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| HLN.L | Haleon | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| HSBA.L | HSBC | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| HSX.L | Hiscox | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| HWDN.L | Howdens Joinery | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| IAG.L | International Airlines Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ICG.L | ICG | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| IGG.L | IG Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| IHG.L | IHG Hotels & Resorts | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| III.L | 3i | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| IMB.L | Imperial Brands | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| IMI.L | IMI | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| INF.L | Informa | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| INVP.L | Investec | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ITRK.L | Intertek | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| JD.L | JD Sports | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| KGF.L | Kingfisher plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| LAND.L | Land Securities | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| LGEN.L | Legal & General | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| LLOY.L | Lloyds Banking Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| LMP.L | LondonMetric Property | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| LSEG.L | London Stock Exchange Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| MKS.L | Marks & Spencer | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| MNG.L | M&G | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| MRO.L | Melrose Industries | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| MTLN.L | Metlen Energy & Metals | LSE | FTSE 100 | false | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| NG.L | National Grid plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| NWG.L | NatWest Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| NXT.L | Next plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| PCT.L | Polar Capital Technology Trust | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| PRU.L | Prudential plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| PSH.L | Pershing Square Holdings | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| PSN.L | Persimmon | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| PSON.L | Pearson plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| REL.L | RELX | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| RIO.L | Rio Tinto | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| RKT.L | Reckitt | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| RR.L | Rolls-Royce Holdings | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| RTO.L | Rentokil Initial | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SBRY.L | Sainsbury's | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SDLF.L | Standard Life | LSE | FTSE 100 | false | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SDR.L | Schroders | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SGE.L | Sage Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SGRO.L | Segro | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SHEL.L | Shell plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SMIN.L | Smiths Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SMT.L | Scottish Mortgage Investment Trust | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SN.L | Smith & Nephew | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SPX.L | Spirax Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SSE.L | SSE plc | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| STAN.L | Standard Chartered | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| STJ.L | St. James's Place | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| SVT.L | Severn Trent | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| TSCO.L | Tesco | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ULVR.L | Unilever | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| UU.L | United Utilities | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| VOD.L | Vodafone Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| WEIR.L | Weir Group | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| WTB.L | Whitbread | LSE | FTSE 100 | true | https://en.wikipedia.org/wiki/FTSE_100_Index | 2026-07-03 |
| ADS.DE | Adidas (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| AIR.PA | Airbus (also: EURO STOXX 50) | Euronext Paris | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| ALV.DE | Allianz (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| BAS.DE | BASF (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| BAYN.DE | Bayer (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| BEI.DE | Beiersdorf | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| BMW.DE | BMW (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| BNR.DE | Brenntag | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| CBK.DE | Commerzbank | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| CON.DE | Continental | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| DB1.DE | Deutsche Börse (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| DBK.DE | Deutsche Bank (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| DHL.DE | Deutsche Post (DHL Group) (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| DTE.DE | Deutsche Telekom (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| DTG.DE | Daimler Truck | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| ENR.DE | Siemens Energy (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| EOAN.DE | E.ON | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| FME.DE | Fresenius Medical Care | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| FRE.DE | Fresenius | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| G1A.DE | GEA Group | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| G24.DE | Scout24 | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| HEI.DE | Heidelberg Materials | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| HEN3.DE | Henkel | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| HNR1.DE | Hannover Re | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| IFX.DE | Infineon Technologies (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| MBG.DE | Mercedes-Benz Group (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| MRK.DE | Merck KGaA | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| MTX.DE | MTU Aero Engines | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| MUV2.DE | Munich Re (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| PAH3.DE | Porsche SE | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| QIA.DE | Qiagen | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| RHM.DE | Rheinmetall (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| RWE.DE | RWE | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| SAP.DE | SAP (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| SHL.DE | Siemens Healthineers | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| SIE.DE | Siemens (also: EURO STOXX 50) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| SY1.DE | Symrise | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| VNA.DE | Vonovia | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| VOW3.DE | Volkswagen Group (pref) | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| ZAL.DE | Zalando | Xetra | DAX 40 | true | https://en.wikipedia.org/wiki/DAX | 2026-07-03 |
| ABI.BR | Anheuser-Busch InBev | Euronext Brussels | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| AD.AS | Ahold Delhaize | Euronext Amsterdam | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| ADYEN.AS | Adyen | Euronext Amsterdam | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| AI.PA | Air Liquide | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| ARGX.BR | Argenx | Euronext Brussels | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| ASML.AS | ASML Holding | Euronext Amsterdam | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| BBVA.MC | BBVA | Bolsa de Madrid | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| BN.PA | Danone | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| BNP.PA | BNP Paribas | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| CS.PA | Axa | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| DG.PA | Vinci SA | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| EL.PA | EssilorLuxottica | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| ENEL.MI | Enel | Borsa Italiana | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| ENI.MI | Eni | Borsa Italiana | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| IBE.MC | Iberdrola | Bolsa de Madrid | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| INGA.AS | ING Group | Euronext Amsterdam | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| ISP.MI | Intesa Sanpaolo | Borsa Italiana | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| ITX.MC | Inditex | Bolsa de Madrid | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| MC.PA | LVMH | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| NDA-FI.HE | Nordea Bank | Nasdaq Helsinki | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| OR.PA | L'Oréal | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| PRX.AS | Prosus | Euronext Amsterdam | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| RACE.MI | Ferrari | Borsa Italiana | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| RMS.PA | Hermès | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| SAF.PA | Safran | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| SAN.MC | Banco Santander | Bolsa de Madrid | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| SAN.PA | Sanofi | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| SGO.PA | Saint-Gobain | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| SU.PA | Schneider Electric | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| TTE.PA | TotalEnergies | Euronext Paris | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| UCG.MI | UniCredit | Borsa Italiana | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| VOW.DE | Volkswagen Group | Frankfurt/Xetra | EURO STOXX 50 | false | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| WKL.AS | Wolters Kluwer | Euronext Amsterdam | EURO STOXX 50 | true | https://en.wikipedia.org/wiki/EURO_STOXX_50 | 2026-07-03 |
| 1332.T | Nissui | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1605.T | Inpex | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1721.T | Comsys Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1801.T | Taisei | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1802.T | Obayashi | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1803.T | Shimizu | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1808.T | Haseko | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1812.T | Kajima | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1925.T | Daiwa House Industry | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1928.T | Sekisui House | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 1963.T | JGC Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2002.T | Nisshin Seifun Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2269.T | Meiji Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2282.T | NH Foods | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2413.T | M3 | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2432.T | Dena | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2501.T | Sapporo Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2502.T | Asahi Group Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2503.T | Kirin Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2768.T | Sojitz | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2801.T | Kikkoman | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2802.T | Ajinomoto | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 285A.T | Kioxia Holdings | Tokyo | Nikkei 225 | false | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2871.T | Nichirei | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 2914.T | Japan Tobacco | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3086.T | J. Front Retailing | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3092.T | ZOZO | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3099.T | Isetan Mitsukoshi Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3289.T | Tokyu Fudosan Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3382.T | Seven & I Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3401.T | Teijin | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3402.T | Toray Industries | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3405.T | Kuraray | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3407.T | Asahi Kasei | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3436.T | SUMCO | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3659.T | Nexon | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3697.T | SHIFT | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 3861.T | Oji Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4004.T | Resonac Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4005.T | Sumitomo Chemical | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4021.T | Nissan Chemical | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4042.T | Tosoh | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4043.T | Tokuyama Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4061.T | Denka | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4063.T | Shin-Etsu Chemical | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4151.T | Kyowa Kirin | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4183.T | Mitsui Chemicals | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4188.T | Mitsubishi Chemical Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4208.T | Ube Industries | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4307.T | Nomura Research Institute | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4324.T | Dentsu Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4385.T | Mercari | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4452.T | Kao | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4502.T | Takeda Pharmaceutical | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4503.T | Astellas Pharma | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4506.T | Sumitomo Pharma | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4507.T | Shionogi | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4519.T | Chugai Pharmaceutical | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4523.T | Eisai | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4543.T | Terumo | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4568.T | Daiichi Sankyo | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4578.T | Otsuka Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4661.T | Oriental Land | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4689.T | LY Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4704.T | Trend Micro | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4751.T | CyberAgent | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4755.T | Rakuten Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4901.T | Fujifilm Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4902.T | Konica Minolta | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 4911.T | Shiseido | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5019.T | Idemitsu Kosan | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5020.T | Eneos Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5101.T | The Yokohama Rubber | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5108.T | Bridgestone | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5201.T | AGC | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5214.T | Nippon Electric Glass | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5233.T | Taiheiyo Cement | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5301.T | Tokai Carbon | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5332.T | Toto | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5333.T | NGK Insulators | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5401.T | Nippon Steel | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5406.T | Kobe Steel | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5411.T | JFE Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 543A.T | Archion | Tokyo | Nikkei 225 | false | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5631.T | The Japan Steel Works | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5706.T | Mitsui Mining & Smelting | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5711.T | Mitsubishi Materials | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5713.T | Sumitomo Metal Mining | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5714.T | Dowa Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5801.T | The Furukawa Electric | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5802.T | Sumitomo Electric Industries | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5803.T | Fujikura | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 5831.T | Shizuoka Financial Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6098.T | Recruit Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6103.T | Okuma Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6113.T | Amada | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6146.T | Disco Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6178.T | Japan Post Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6273.T | SMC Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6301.T | Komatsu | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6302.T | Sumitomo Heavy Industries | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6305.T | Hitachi Construction Machinery | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6326.T | Kubota | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6361.T | Ebara | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6367.T | Daikin Industries | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6471.T | NSK | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6472.T | NTN | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6473.T | JTEKT | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6479.T | MinebeaMitsumi | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6501.T | Hitachi | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6503.T | Mitsubishi Electric | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6504.T | Fuji Electric | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6506.T | Yaskawa Electric | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6526.T | Socionext | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6532.T | Baycurrent | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6594.T | Nidec | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6645.T | Omron | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6701.T | NEC | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6702.T | Fujitsu | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6723.T | Renesas Electronics | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6724.T | Seiko Epson | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6752.T | Panasonic Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6753.T | Sharp Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6758.T | Sony Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6762.T | TDK | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6770.T | Alps Alpine | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6841.T | Yokogawa Electric | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6857.T | Advantest | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6861.T | Keyence | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6902.T | Denso | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6920.T | Lasertec | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6954.T | FANUC | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6963.T | Rohm | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6971.T | Kyocera | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6976.T | Taiyo Yuden | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6981.T | Murata Manufacturing | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 6988.T | Nitto Denko | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7004.T | Kanadevia | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7011.T | Mitsubishi Heavy Industries | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7012.T | Kawasaki Heavy Industries | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7013.T | IHI | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7186.T | Concordia Financial Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7201.T | Nissan Motor | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7202.T | Isuzu Motors | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7203.T | Toyota Motor | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7211.T | Mitsubishi Motors | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7261.T | Mazda Motor | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7267.T | Honda Motor | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7269.T | Suzuki Motor | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7270.T | Subaru | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7272.T | Yamaha Motor Company | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7453.T | Ryohin Keikaku (Muji) | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7532.T | Pan Pacific International Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7731.T | Nikon | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7733.T | Olympus | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7735.T | SCREEN Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7741.T | Hoya Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7751.T | Canon | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7752.T | Ricoh | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7832.T | Bandai Namco Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7911.T | Toppan Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7912.T | Dai Nippon Printing | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7951.T | Yamaha Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 7974.T | Nintendo | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8001.T | Itochu | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8002.T | Marubeni | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8015.T | Toyota Tsusho | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8031.T | Mitsui & Co. | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8035.T | Tokyo Electron | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8053.T | Sumitomo Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8058.T | Mitsubishi Corporation | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8233.T | Takashimaya | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8252.T | Marui Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8253.T | Credit Saison | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8267.T | Aeon | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8304.T | Aozora Bank | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8306.T | Mitsubishi UFJ Financial Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8308.T | Resona Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8309.T | Sumitomo Mitsui Trust Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8316.T | Sumitomo Mitsui Financial Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8331.T | The Chiba Bank | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8354.T | Fukuoka Financial Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8411.T | Mizuho Financial Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8591.T | Orix | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8601.T | Daiwa Securities Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8604.T | Nomura Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8630.T | Sompo Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8697.T | Japan Exchange Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8725.T | MS&AD Insurance Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8750.T | Dai-ichi Life Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8766.T | Tokio Marine Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8795.T | T&D Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8801.T | Mitsui Fudosan | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8802.T | Mitsubishi Estate | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8804.T | Tokyo Tatemono | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 8830.T | Sumitomo Realty & Development | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9001.T | Tobu Railway | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9005.T | Tokyu | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9007.T | Odakyu Electric Railway | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9008.T | Keio | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9009.T | Keisei Electric Railway | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9020.T | East Japan Railway | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9021.T | West Japan Railway | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9022.T | Central Japan Railway | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9064.T | Yamato Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9101.T | Nippon Yusen | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9104.T | Mitsui O.S.K. Lines | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9107.T | Kawasaki Kisen Kaisha | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9147.T | Nippon Express Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9201.T | Japan Airlines | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9202.T | ANA Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9432.T | Nippon Telegraph & Telephone | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9433.T | KDDI | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9434.T | SoftBank | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9501.T | Tokyo Electric Power Company | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9502.T | Chubu Electric Power | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9503.T | The Kansai Electric Power | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9602.T | Toho | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9735.T | Secom | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9766.T | Konami Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9843.T | Nitori Holdings | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9983.T | Fast Retailing | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |
| 9984.T | SoftBank Group | Tokyo | Nikkei 225 | true | https://en.wikipedia.org/wiki/Nikkei_225 | 2026-07-03 |

## Footer

- **Total unique candidate symbols:** 1413
- **Rows with suffixVerified=false (inferred, MUST verify via Yahoo-v8):** 6
- **Total source rows before dedupe:** 1517  (deduped to 1413; 104 cross-index duplicates collapsed)

### Unique candidates by primary group
- S&P 500: 416
- Nasdaq-100: 101
- S&P MidCap 400 (surplus): 400
- Tadawul (Saudi, PRIORITY): 100
- FTSE 100: 100
- DAX 40: 40
- EURO STOXX 50: 33
- Nikkei 225: 223
