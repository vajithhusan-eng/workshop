"""Seed data — canon, SEBI stats, starter books/channels, techniques.
All numbers are from verified research (see projects/omnivest/PLAN.md).
"""

from __future__ import annotations

CONSENSUS_8 = [
    {
        "id": "circle",
        "rule": "Circle of competence",
        "line": "The size of that circle is not very important; knowing its boundaries, however, is vital. — Buffett, 1996",
    },
    {
        "id": "understand",
        "rule": "Understand before you buy",
        "line": "How to make money in stocks is not to get scared out of them. — Lynch",
    },
    {
        "id": "moat",
        "rule": "A moat must exist",
        "line": "I try to buy stock in businesses that are so wonderful that an idiot can run them. — Buffett",
    },
    {
        "id": "mos",
        "rule": "Margin of safety",
        "line": "Quality meeting criteria, trading below intrinsic value — Graham",
    },
    {
        "id": "contrarian",
        "rule": "Be contrarian",
        "line": "Lynch used institutional ownership as a gauge — higher ownership = less likely to buy",
    },
    {
        "id": "inventory",
        "rule": "Watch the inventory",
        "line": "Inventory buildup usually points to underlying problems — Lynch",
    },
    {
        "id": "emotions",
        "rule": "Control your emotions",
        "line": "Individuals who cannot master their emotions are ill-suited to profit from the investment process. — Graham",
    },
    {
        "id": "monitor",
        "rule": "Not buy-and-forget",
        "line": "All three agree: you must know when to exit",
    },
]

DEBATES = [
    {
        "id": "cash-vs-equities",
        "question": "Should you hold cash or stay fully invested?",
        "buffett": "Berkshire sat on ~$124B cash and grew it. Optionality + survival.",
        "dalio": "Holding cash is 'one of the worst mistakes an investor could possibly make' — inflation erodes it.",
        "damodaran": "Cash is a wasting asset in inflation, an option in a crash. Price the option honestly.",
        "evidence": "McLean & Pontiff (2016): post-publication returns 58% lower — any published 'answer' decays once crowded.",
    },
    {
        "id": "concentrate-vs-diversify",
        "question": "5–10 positions (Buffett) or hundreds globally (Dalio)?",
        "buffett": "Concentrated value — 5–10 core positions, hold forever.",
        "dalio": "Systematic macro / risk parity — diversify across uncorrelated assets.",
        "damodaran": "Diversification protects against your own overconfidence; concentration only works with permanent capital.",
        "evidence": "Buffett built structural capital (insurance float); Graham needed smallness — true net-nets die as capital grows.",
    },
    {
        "id": "macro-matters",
        "question": "Is macro forecasting useful for stock picking?",
        "buffett": "'Useless for stock picking' — ignore it.",
        "dalio": "Core of the investment process — cycles drive everything.",
        "damodaran": "Macro explains variance but rarely gives a tradeable edge to retail.",
        "evidence": "JPM Aug 2026: momentum only factor positive across all DM+EM in Q2 2026 — regime-conditional, not permanent.",
    },
    {
        "id": "gold",
        "question": "Gold: productive asset or pet rock?",
        "buffett": "Non-productive asset, never buy.",
        "dalio": "Important inflation hedge.",
        "damodaran": "A hedge with a negative expected real return — size it as insurance, not investment.",
        "evidence": "State Street Jun 2026: in defensives, valuation+quality beat sentiment over 20y.",
    },
    {
        "id": "direct-vs-regular",
        "question": "Direct vs Regular mutual funds — what actually costs you?",
        "buffett": "N/A — but fees compound against you for decades.",
        "dalio": "N/A — but behaviour compounds harder.",
        "damodaran": "Cost-of-fee vs cost-of-decision: fund selection dominates by ~10x.",
        "evidence": "1 Finance Jan 2026: 80%+ of equity schemes leave regular investors ≥25% worse off over 10y. Feroze Azeez Feb 2026: best vs worst fund = ₹11.61L gap on ₹1L — behaviour costs more than fees.",
    },
]

SEBI_FY26 = {
    "source": "SEBI PR No.50/2026 (DEPA), released 20 Aug 2026, FY26",
    "active_traders_lakh": {"fy25": 98.1, "fy26": 78.6, "change": "-20%"},
    "new_entrants_change": "-40%",
    "loss_rate": 87.7,
    "aggregate_net_loss_crore": 91685,
    "avg_loss_per_trader": 117000,
    "options_share_of_losses": 92,
    "txn_costs_fy26_crore": 25000,
    "txn_costs_cumulative_fy22_26_crore": 100000,
    "algo_share_of_pro_profits": 99,
    "prior": {
        "fy22_24_loss_rate": 92.8,
        "fy22_24_agg_loss_crore": 181000,
        "under30_share_fy24": 43,
        "under30_loss_rate": 93,
        "kept_trading_after_losses": 75,
    },
}

STARTER_BOOKS = [
    {
        "title": "The Intelligent Investor",
        "author": "Benjamin Graham",
        "year": 1949,
        "idea": "Margin of safety",
        "pd_india": "2037 — NOT free, lessons+citation only",
    },
    {
        "title": "Security Analysis",
        "author": "Graham & Dodd",
        "year": 1934,
        "idea": "Assets vs earning power",
        "pd_india": "2037 — NOT free",
    },
    {
        "title": "Reminiscences of a Stock Operator",
        "author": "Edwin Lefèvre",
        "year": 1923,
        "idea": "Tape-reading psychology",
        "pd_india": "FREE since 2004 ✅",
    },
    {
        "title": "One Up on Wall Street",
        "author": "Peter Lynch",
        "year": 1989,
        "idea": "Buy what you know; watch inventory; ≤25% debt",
    },
    {
        "title": "The Psychology of Money",
        "author": "Morgan Housel",
        "year": 2020,
        "idea": "Behaviour > math",
    },
    {
        "title": "Principles",
        "author": "Ray Dalio",
        "year": 2017,
        "idea": "Radical truth + diversification across cycles",
    },
    {
        "title": "Poor Charlie's Almanack",
        "author": "Charlie Munger",
        "year": 2005,
        "idea": "Inversion — avoid stupidity first",
    },
    {
        "title": "Common Stocks and Uncommon Profits",
        "author": "Philip Fisher",
        "year": 1958,
        "idea": "Scuttlebutt + quality management",
    },
    {
        "title": "The Little Book That Builds Wealth",
        "author": "Pat Dorsey",
        "year": 2008,
        "idea": "4 moat sources: intangibles, cost, switching, network",
    },
    {
        "title": "Investonomy",
        "author": "Pranjal Kamra",
        "year": 2022,
        "idea": "Indian value investing for beginners",
    },
]

CHANNELS = [
    {
        "name": "CA Rachana Phadke Ranade",
        "subs": "5.3M",
        "lang": "EN/HI",
        "focus": "Beginner fundamentals, balance sheets, SIP/MF",
    },
    {
        "name": "Pranjal Kamra / Finology",
        "subs": "6.5M",
        "lang": "HI/EN",
        "focus": "Value investing, money mindset (sells paid research)",
    },
    {
        "name": "Zerodha Varsity (Karthik Rangappa)",
        "subs": "course-led",
        "lang": "EN",
        "focus": "Most curriculum-like: TA, F&O, fundamentals, psychology",
    },
    {
        "name": "Elearnmarkets / StockEdge (Vivek Bajaj)",
        "subs": "~1M",
        "lang": "EN/HI",
        "focus": "TA, derivatives, #Face2Face podcast",
    },
    {
        "name": "Yadnya Investment Academy",
        "subs": "935K",
        "lang": "EN/HI",
        "focus": "MFs, SIP, planning",
    },
    {
        "name": "Invest Aaj For Kal (Anant Ladha)",
        "subs": "3M",
        "lang": "HI",
        "focus": "MFs, personal finance",
    },
    {
        "name": "Asset Yogi",
        "subs": "3.9M",
        "lang": "HI",
        "focus": "Real estate + investing basics",
    },
    {
        "name": "Sunil Minglani",
        "subs": "1.43M",
        "lang": "HI",
        "focus": "Trading psychology",
    },
    {
        "name": "Trade Brains",
        "subs": "528K",
        "lang": "EN/HI",
        "focus": "Simplified valuations, strategies",
    },
    {
        "name": "CNBC Awaaz",
        "subs": "6.26M",
        "lang": "HI",
        "focus": "24x7 Hindi market live",
    },
]

TECHNIQUES = [
    {
        "id": "momentum-12-1",
        "name": "Momentum 12-1",
        "in_sample": "+309bps (Nifty500 Mom50 vs Nifty500, since 2005)",
        "live_1y": "-2.5% vs +14.1% parent (Jul 2026 factsheet) ⚠️ underperforming",
        "decay_note": "McLean & Pontiff: post-pub −58%. Daniel & Moskowitz: worst month −78.96% (Aug 1932).",
        "regime": "Bull-market conditional (Motilal Oswal). Worst in rebounds after drawdowns.",
        "pbo_hint": "Elevated comomentum → scale down (Lou & Polk 2022). Nov 2020: −5% in one day on vaccine news.",
    },
    {
        "id": "value-book-to-market",
        "name": "Value (book-to-market)",
        "in_sample": "Led 2025 + Q1 2026 (Morningstar)",
        "live_1y": "Now historically inexpensive per JPM Aug 2026",
        "decay_note": "Harvey-Liu-Zhu: most claimed factors likely false at t<3. FDR calibration required.",
        "regime": "Works in defensives over 20y (State Street). Dies in crowded growth rotations.",
        "pbo_hint": "Trials>1 ⇒ overfitting always present (Bailey et al. proof). Use DSR, not Sharpe.",
    },
    {
        "id": "ml-stock-predictor",
        "name": "ML stock predictor (trees/NN)",
        "in_sample": "R² 0.33–0.40% monthly (Gu-Kelly-Xiu 2020)",
        "live_1y": "Ceiling, not floor. Shallow NNs beat transformers (2025).",
        "decay_note": "Gains come from interactions of known predictors, not new info. Anyone claiming 60–70% accuracy is overfitting or lying.",
        "regime": "Portfolio aggregation averages out noise — stock-level forecasts stay near-zero.",
        "pbo_hint": "Use elastic net, publish MinBTL/MinTRL, never deep learning for this.",
    },
]
