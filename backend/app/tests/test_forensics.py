"""Forensics test suite. No pytest dependency — runs on the bare venv.

    cd backend && ./.venv/bin/python -m app.tests.test_forensics

The properties asserted here are the ones the product's thesis depends on.
If any of these break, OMNIVEST is lying to its users, so they are not
optional decoration.
"""

from __future__ import annotations

import math
import random

from app.forensics import (
    autopsy,
    deflated_sharpe,
    excess_kurtosis,
    fdr_adjusted_pvalue,
    kurtosis,
    min_backtest_length,
    momentum_crash_risk,
    norm_cdf,
    norm_ppf,
    pbo_cscv,
    psr,
    sharpe,
    sharpe_frontier,
    skewness,
)

FAILURES: list[str] = []
PASSED = 0


def check(name: str, condition: bool, detail: str = "") -> None:
    global PASSED
    if condition:
        PASSED += 1
        print(f"  PASS  {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"  FAIL  {name}  {detail}")


def close(a: float, b: float, tol: float = 1e-6) -> bool:
    return abs(a - b) <= tol


# ── normal distribution ─────────────────────────────────────────────────────


def test_norm() -> None:
    print("\n[normal distribution]")
    check("cdf(0) == 0.5", close(norm_cdf(0.0), 0.5, 1e-12), f"{norm_cdf(0.0)}")
    check("ppf(0.5) == 0", close(norm_ppf(0.5), 0.0, 1e-6), f"{norm_ppf(0.5)}")
    check(
        "ppf(0.975) == 1.95996",
        close(norm_ppf(0.975), 1.959964, 1e-4),
        f"{norm_ppf(0.975)}",
    )
    check(
        "ppf(0.025) == -1.95996",
        close(norm_ppf(0.025), -1.959964, 1e-4),
        f"{norm_ppf(0.025)}",
    )
    check(
        "ppf(0.95) == 1.64485",
        close(norm_ppf(0.95), 1.644854, 1e-4),
        f"{norm_ppf(0.95)}",
    )
    # round-trip
    for p in (0.01, 0.1, 0.3, 0.7, 0.9, 0.99):
        check(f"round-trip p={p}", close(norm_cdf(norm_ppf(p)), p, 1e-9))
    # monotonicity
    check(
        "ppf monotonic",
        all(
            norm_ppf(a) < norm_ppf(b) for a, b in ((0.1, 0.2), (0.5, 0.6), (0.9, 0.99))
        ),
    )


# ── return statistics ───────────────────────────────────────────────────────


def test_stats() -> None:
    print("\n[return statistics]")
    xs = [0.01, -0.02, 0.03, 0.00, -0.01, 0.02, 0.005, -0.015]
    check("mean is correct", close(sum(xs) / len(xs), sum(xs) / 8))
    check("stdev > 0", stdev_of(xs) > 0)
    check("skew finite", math.isfinite(skewness(xs)))
    check("kurtosis finite", math.isfinite(kurtosis(xs)))
    # symmetric data => ~0 skew
    sym = [-0.02, -0.01, 0.0, 0.01, 0.02, -0.015, 0.015]
    check("symmetric skew ~ 0", abs(skewness(sym)) < 0.5, f"{skewness(sym)}")
    # RAW kurtosis on a large Gaussian sample converges to 3.0 — this is the
    # property PSR depends on, so it is the one worth pinning.
    rng_k = random.Random(11)
    gauss = [rng_k.gauss(0.0, 0.01) for _ in range(20000)]
    check(
        "Gaussian raw kurtosis ~ 3",
        abs(kurtosis(gauss) - 3.0) < 0.15,
        f"{kurtosis(gauss)}",
    )
    check(
        "excess_kurtosis = raw - 3",
        abs(excess_kurtosis(gauss) - (kurtosis(gauss) - 3.0)) < 1e-12,
    )
    # fat tails show up as positive excess
    fat = [
        rng_k.gauss(0.0, 0.01) * (3.0 if rng_k.random() < 0.05 else 1.0)
        for _ in range(20000)
    ]
    check(
        "fat tails => positive excess kurtosis",
        excess_kurtosis(fat) > 0.3,
        f"{excess_kurtosis(fat)}",
    )
    # tiny sample => platykurtic, but must still be finite and positive
    check("small symmetric sample is finite", math.isfinite(kurtosis(sym)))
    # zero variance guard
    check("stdev of constants == 0", stdev_of([0.01] * 5) == 0.0)
    check("sharpe of constants == 0", sharpe([0.01] * 5) == 0.0)
    check("kurtosis of constants == 3", kurtosis([0.01] * 5) == 3.0)


def stdev_of(xs):
    from app.forensics import stdev

    return stdev(xs)


# ── Sharpe Ratio Efficient Frontier [BLdP12] ───────────────────────────────


def test_frontier() -> None:
    print("\n[Sharpe Ratio Efficient Frontier - Bailey & LdP 2012]")
    f1 = sharpe_frontier(1, 1.0)
    f10 = sharpe_frontier(10, 1.0)
    f100 = sharpe_frontier(100, 1.0)
    check("frontier(1) >= 0", f1 >= 0, f"{f1}")
    check("frontier increases with trials", f1 < f10 < f100, f"{f1},{f10},{f100}")
    # Known: with N=2 the frontier is small; with N=100 it approaches ~2.5-2.7
    check("frontier(100) in [2.0, 3.2]", 2.0 < f100 < 3.2, f"{f100}")
    # Scaling in sigma is linear
    check(
        "frontier linear in sigma",
        close(sharpe_frontier(50, 2.0), 2 * sharpe_frontier(50, 1.0), 1e-9),
    )
    # N=1: the max of a single draw is its own mean, i.e. zero. Regression guard —
    # the formula's 1-1/N term collapses to exactly 0 and used to crash.
    check(
        "frontier(1) == 0 (no search, no luck)",
        sharpe_frontier(1, 1.0) == 0.0,
        f"{sharpe_frontier(1, 1.0)}",
    )
    check(
        "frontier(2) is the first real step up",
        sharpe_frontier(2, 1.0) > 0.4,
        f"{sharpe_frontier(2, 1.0)}",
    )
    check("frontier(2) finite", math.isfinite(sharpe_frontier(2, 1.0)))
    # absurd N must not blow up on float underflow
    check(
        "frontier(1e12) finite and non-negative",
        math.isfinite(sharpe_frontier(10**12, 1.0))
        and sharpe_frontier(10**12, 1.0) > 0,
        f"{sharpe_frontier(10**12, 1.0)}",
    )
    try:
        sharpe_frontier(0, 1.0)
        check("rejects n_trials=0", False, "no exception")
    except ValueError:
        check("rejects n_trials=0", True)


# ── PSR / DSR [BLdP14] ──────────────────────────────────────────────────────


def test_psr_dsr() -> None:
    print("\n[PSR / DSR - Bailey & LdP 2014]")
    # No edge, no benchmark => coin flip
    check(
        "PSR(0,0,n) == 0.5",
        close(psr(0.0, 0.0, 1000), 0.5, 1e-9),
        f"{psr(0.0, 0.0, 1000)}",
    )
    # Higher observed SR => higher PSR
    check("PSR monotone in observed", psr(0.5, 0.0, 1000) > psr(0.0, 0.0, 1000))
    # Higher benchmark => lower PSR
    check("PSR monotone in benchmark", psr(0.5, 0.2, 1000) > psr(0.5, 0.8, 1000))
    # More observations => more confidence
    check("PSR rises with n", psr(0.4, 0.3, 2000) > psr(0.4, 0.3, 200))
    # Fat tails and negative skew must lower PSR at equal Sharpe (they inflate
    # the denominator). The values are chosen so the z-score sits in the
    # sensitive mid-range of the normal CDF:
    #   - too LARGE an SR/observation count and norm_cdf rounds to exactly
    #     1.0 in float64, making every comparison vacuously false;
    #   - too SMALL an SR and the kurtosis term (g4-1)/4 * SR^2 is negligible.
    # The saturation guard below pins this so the test cannot go quiet.
    SR, NOBS = 0.3, 30
    base = psr(SR, 0.0, NOBS)
    fat = psr(SR, 0.0, NOBS, kurt=8.0)
    skewy = psr(SR, 0.0, NOBS, skew=-1.5)
    check(
        "PSR comparisons are not saturated (GUARD)",
        0.001 < base < 0.999,
        f"base={base}",
    )
    check("fat tails lower PSR", fat < base, f"{fat} vs {base}")
    check("negative skew lowers PSR", skewy < base, f"{skewy} vs {base}")
    # ...and the effects are material rather than rounding noise
    check("kurtosis effect is material", base - fat > 0.002, f"gap={base - fat}")
    check("skew effect is material", base - skewy > 0.002, f"gap={base - skewy}")
    # saturation is real behaviour; assert it explicitly rather than
    # accidentally depending on it elsewhere in this suite
    check("PSR saturates at 1.0 for huge z", psr(0.5, 0.0, 1000) == 1.0)

    # DSR must punish trial count. This is the whole point of deflation.
    few = deflated_sharpe(0.6, 2, 1000)
    many = deflated_sharpe(0.6, 500, 1000)
    check(
        "DSR falls as trials rise",
        few["dsr"] > many["dsr"],
        f"2 trials {few['dsr']} vs 500 trials {many['dsr']}",
    )
    check(
        "500 trials @ SR 0.6 is not significant",
        many["significant"] is False,
        f"{many}",
    )
    check("1 trial @ SR 0.6 is significant", few["significant"] is True, f"{few}")
    # A truly lucky-only result reads as indistinguishable from luck
    check(
        "SR 0.2 with 1000 trials -> luck",
        deflated_sharpe(0.2, 1000, 500)["dsr"] < 0.05,
        f"{deflated_sharpe(0.2, 1000, 500)}",
    )
    # A monster Sharpe survives a big search
    check(
        "SR 3.0 with 1000 trials survives",
        deflated_sharpe(3.0, 1000, 5000)["significant"] is True,
        f"{deflated_sharpe(3.0, 1000, 5000)}",
    )


# ── PBO via CSCV [BBLP17] ───────────────────────────────────────────────────


def test_pbo() -> None:
    print("\n[PBO via CSCV - Bailey et al. 2017]")
    rng = random.Random(20260930)

    # --- property 1: pure noise has no skill to select --------------------
    # Averaged over independent replications, because a single CSCV estimate is
    # a poor read of the null and tuning an assertion to one lucky seed is how
    # tests end up asserting nothing.
    n_strat, n_periods = 20, 480
    noise_pbos = []
    for rep in range(8):
        r = random.Random(1000 + rep)
        draws = [
            [r.gauss(0.0004, 0.015) for _ in range(n_periods)] for _ in range(n_strat)
        ]
        noise_pbos.append(pbo_cscv(draws, n_splits=8)["pbo"])
    p_noise_mean = sum(noise_pbos) / len(noise_pbos)
    # The mean must sit near 0.5. Individual draws are NOT tight around it: the
    # C(S, S/2) splits share subperiods, so they are heavily dependent and one
    # PBO is far noisier than a binomial with n=70 suggests (observed spread
    # ~0.15 to ~0.74). Asserting a tight per-draw band would be asserting
    # noise, so the tolerance lives on the mean and the spread is itself
    # asserted as a documented caveat about reading a single PBO.
    check(
        "mean noise PBO is near a coin flip",
        0.38 <= p_noise_mean <= 0.62,
        f"mean={p_noise_mean:.3f} draws={noise_pbos}",
    )
    check(
        "noise PBO is a probability",
        all(0.0 <= p <= 1.0 for p in noise_pbos),
        f"draws={noise_pbos}",
    )
    spread = max(noise_pbos) - min(noise_pbos)
    check(
        "single-draw PBO is materially noisy (CAVEAT)",
        spread > 0.2,
        f"spread={spread:.3f} across 8 pure-noise draws",
    )

    # --- property 2: a real edge should look investable, PBO low ---------
    true_alpha = 0.004  # per-period alpha
    real = [
        [rng.gauss(true_alpha, 0.015) + 0.0 for _ in range(n_periods)]
        for _ in range(n_strat)
    ]
    # give a few strategies a genuine, varied edge
    for s in range(0, 5):
        real[s] = [
            rng.gauss(true_alpha * (1 + 0.2 * s), 0.015) for _ in range(n_periods)
        ]
    p_real = pbo_cscv(real, n_splits=8)
    check("real-edge PBO < 0.5", p_real["pbo"] < 0.5, f"PBO={p_real['pbo']}")
    check(
        "real edge scores better than noise",
        p_real["pbo"] < noise_pbos[0] and p_real["pbo"] < p_noise_mean,
        f"real {p_real['pbo']} vs noise mean {p_noise_mean:.3f}",
    )
    # The decisive regression guard for the logit SIGN: a stable in-sample
    # winner finishes above the OOS median, so omega < 0.5 and its logit is
    # strongly negative. Flip the sign and this goes to +inf, reporting PBO
    # 1.0 ("negative skill") for a perfectly consistent strategy.
    check(
        "stable winner's logit is NEGATIVE (SIGN GUARD)",
        p_real["best_oos_rank_logit"] < 0.0,
        f"best={p_real['best_oos_rank_logit']}",
    )
    check(
        "a stable winner contributes 0 to PBO",
        p_real["pbo"] == 0.0,
        f"PBO={p_real['pbo']}",
    )

    # --- property 3: PBO is in [0,1] and reports its inputs ---------------
    check("PBO bounded", all(0.0 <= p <= 1.0 for p in noise_pbos + [p_real["pbo"]]))
    check(
        "PBO reports n_combos",
        p_real["n_combos"] == 70,
        f"expected C(8,4)=70, got {p_real['n_combos']}",
    )
    check("PBO reports strategy count", p_real["n_strategies"] == n_strat)

    # --- property 4: N=2 is the degenerate but valid case ------------------
    two = [[rng.gauss(0, 0.01) for _ in range(240)] for _ in range(2)]
    p_two = pbo_cscv(two, n_splits=8)
    check("N=2 works", "pbo" in p_two)

    # --- property 5: perfect anti-CORRELATION is not anti-PERSISTENCE ------
    # down is the exact negation of up. Both still have positive drift, so up
    # wins in-sample AND out-of-sample on every split: PBO 0. This is the
    # distinction that trips people up — negating a series is not the same as
    # making its winner reverse, and only the latter is overfitting.
    rng2 = random.Random(7)
    up = [rng2.gauss(0.02, 0.005) for _ in range(480)]
    down = [-x for x in up]
    p_anti = pbo_cscv([up, down], n_splits=8)
    check(
        "negated (not reversed) strategies => PBO 0",
        p_anti["pbo"] == 0.0,
        f"PBO={p_anti['pbo']}",
    )
    check(
        "negated strategies keep a negative logit",
        p_anti["worst_oos_rank_logit"] < 0.0,
        f"worst={p_anti['worst_oos_rank_logit']}",
    )

    # --- guards ------------------------------------------------------------
    for bad, msg in (
        (lambda: pbo_cscv([[0.01] * 100]), "1 strategy"),
        (lambda: pbo_cscv([[0.01] * 100, [0.02] * 100], n_splits=7), "odd n_splits"),
        (lambda: pbo_cscv([[0.01] * 2, [0.02] * 2], n_splits=8), "too few periods"),
    ):
        try:
            bad()
            check(f"rejects {msg}", False, "no exception raised")
        except ValueError:
            check(f"rejects {msg}", True)


def test_pbo_rank_last() -> None:
    """Hand-derived deterministic test of the rank=last boundary.

    Every value below is computed by hand from the construction, so this pins
    the rank -> omega -> logit -> PBO mapping exactly rather than asserting
    whatever the RNG happens to produce today.

    Construction: 2 strategies, 8 periods, n_splits=4, so each block is 2
    periods and the splits are the 6 pairs {0,1},{0,2},{0,3},{1,2},{1,3},{2,3}.

        A = [+2,-1, +2,-1, -2,+1, -2,+1]      blocks 0,1 up   blocks 2,3 down
        B = -A

    A's IS/OOS Sharpe for each split (periods_per_year cancels in the ranking):

        {0,1} IS  A = +0.408  -> A wins IS
             {2,3} OOS A = -0.408 -> A is LAST  -> rank 2 -> omega 0.75
                                                       -> logit ln(3) = +1.0986
        {2,3} IS  A = -0.408  -> B wins IS
             {0,1} OOS A = +0.408 -> B is LAST  -> rank 2 -> logit +1.0986
        {0,2},{0,3},{1,2},{1,3}: A's in-sample and out-of-sample blocks
             cancel to mean 0, so the Shandles are exactly 0.0 and the tie
             resolves to rank 1 -> omega 0.25 -> logit -1.0986

    Therefore PBO = 2 of 6 = 0.3333, worst logit +ln(3), best logit -ln(3).

    This is the case that crashed the original implementation: rank 2 of 2
    under a rank/N convention gives omega = 1.0 and log(1/0) -> ZeroDivisionError.
    """
    print("\n[PBO rank boundary - deterministic, hand-derived]")
    a = [2.0, -1.0, 2.0, -1.0, -2.0, 1.0, -2.0, 1.0]
    b = [-x for x in a]
    p = pbo_cscv([a, b], n_splits=4)

    check("n_combos is C(4,2)=6", p["n_combos"] == 6, f"{p['n_combos']}")
    check("PBO is exactly 2/6", close(p["pbo"], 2 / 6, 1e-4), f"{p['pbo']}")
    check(
        "worst logit is +ln(3)",
        close(p["worst_oos_rank_logit"], math.log(3), 1e-4),
        f"{p['worst_oos_rank_logit']}",
    )
    check(
        "best logit is -ln(3)",
        close(p["best_oos_rank_logit"], -math.log(3), 1e-4),
        f"{p['best_oos_rank_logit']}",
    )
    check(
        "logits stay finite at the last rank (ZERO-DIV GUARD)",
        math.isfinite(p["worst_oos_rank_logit"]),
    )
    check(
        "finishing last is counted as overfit (SIGN GUARD)",
        p["worst_oos_rank_logit"] > 0.0 and p["best_oos_rank_logit"] < 0.0,
        f"worst={p['worst_oos_rank_logit']} best={p['best_oos_rank_logit']}",
    )


# ── MinBTL ──────────────────────────────────────────────────────────────────


def test_minbtl() -> None:
    print("\n[MinBTL]")

    # ── the headline result, and the reason the product exists ────────────
    # To claim a Sharpe of 0.5 you need ~36 years of daily bars:
    # power = (3 * sqrt(252) / 0.5)^2 ~ 9,070 observations.
    obs = min_backtest_length(100, 0.5)
    check(
        "MinBTL(100, 0.5) needs 30-40 years of daily data",
        30 * 252 < obs < 40 * 252,
        f"{obs} ({obs / 252:.1f}y)",
    )
    # a typical retail backtest must NOT clear it
    check(
        "3 years of daily data does NOT pass MinBTL(100, 0.5)",
        3 * 252 < obs,
        f"{3 * 252} vs {obs}",
    )
    check(
        "10 years of daily data does NOT pass MinBTL(100, 0.5)",
        10 * 252 < obs,
        f"{10 * 252} vs {obs}",
    )
    check(
        "40 years of daily data passes MinBTL(100, 0.5)",
        40 * 252 >= obs,
        f"{40 * 252} vs {obs}",
    )

    # ── which term binds is the actual insight ──────────────────────────
    # power binds whenever the frontier multiplier mult(N) < confidence_z = 3,
    # i.e. for roughly N < 500. Below that crossover, searching more variants
    # costs nothing extra: the binding constraint is that you cannot yet
    # MEASURE the effect at all, and no amount of extra trials changes that.
    check(
        "MinBTL is flat in trials below the crossover",
        min_backtest_length(10, 0.5) == obs == min_backtest_length(400, 0.5),
        f"10={min_backtest_length(10, 0.5)} 100={obs} "
        f"400={min_backtest_length(400, 0.5)}",
    )
    # above the crossover deflation takes over and trials start to matter again
    big = min_backtest_length(1000, 0.5)
    check("MinBTL rises again past ~500 trials", big > obs, f"{big} vs {obs}")
    check(
        "MinBTL is monotone in trials once deflation binds",
        min_backtest_length(500, 0.5) <= min_backtest_length(2000, 0.5),
        f"500={min_backtest_length(500, 0.5)} 2000={min_backtest_length(2000, 0.5)}",
    )
    check(
        "MinBTL rises as target Sharpe falls",
        min_backtest_length(50, 0.2) > min_backtest_length(50, 1.0),
    )

    # ── power floor: a single trial still needs real data ───────────────
    # The deflation term is 0 at n_trials=1, so without the power requirement
    # this returns 0 observations and licenses "no data needed at all".
    one = min_backtest_length(1, 0.5)
    check("MinBTL(1, 0.5) is NOT zero", one > 0, f"{one}")
    check(
        "MinBTL(1, 0.5) equals the power requirement",
        close(one, (3 * math.sqrt(252) / 0.5) ** 2, 1.0),
        f"{one}",
    )

    # ── a big, specific target is reachable in sane time ────────────────
    easy = min_backtest_length(3, 1.5)
    check("MinBTL(3, 1.5) needs under 5 years", easy < 5 * 252, f"{easy}")
    check("MinBTL(3, 1.5) needs over a quarter", easy > 63, f"{easy}")
    check(
        "MinBTL(3, 1.5) is under an eighth of MinBTL(100, 0.5)",
        easy < obs / 8,
        f"{easy} vs {obs}",
    )

    # scaling the confidence hurdle scales the requirement quadratically
    loose = min_backtest_length(1, 0.5, confidence_z=2.0)
    check(
        "a 2-sigma hurdle needs ~2.25x fewer obs (z is squared)",
        abs(loose * 2.25 - one) < 1.0,
        f"loose={loose} strict={one}",
    )

    # units sanity: scaling periods_per_year by 4 (quarterly) must quarter the
    # required observation count, because each observation carries more signal
    q = min_backtest_length(100, 0.5, periods_per_year=63)
    check(
        "quarterly frequency needs ~1/4 the observations",
        abs(q - obs / 4) < 1.0,
        f"quarterly {q} vs daily {obs}",
    )
    for bad, msg in (
        (lambda: min_backtest_length(10, 0.0), "zero target"),
        (lambda: min_backtest_length(10, -1.0), "negative target"),
        (lambda: min_backtest_length(10, 0.5, confidence_z=0.0), "zero z"),
    ):
        try:
            bad()
            check(f"rejects {msg}", False, "no exception raised")
        except ValueError:
            check(f"rejects {msg}", True)


# ── FDR [HLZ16 / HL20] ──────────────────────────────────────────────────────


def test_fdr() -> None:
    print("\n[FDR calibration - Harvey/Liu/Zhu]")
    weak = fdr_adjusted_pvalue(2.1, 1, 0.05)
    check("t=2.1 with 1 test passes FDR", weak["passes"] is True, f"{weak}")
    check("t=2.1 does not clear HLZ 3", weak["clears_hlz_3"] is False)

    # the same t-stat fails once you've searched a lot of papers
    searched = fdr_adjusted_pvalue(2.1, 300, 0.05)
    check("t=2.1 with 300 tests fails FDR", searched["passes"] is False, f"{searched}")

    strong = fdr_adjusted_pvalue(4.0, 300, 0.05)
    check("t=4.0 with 300 tests passes", strong["passes"] is True, f"{strong}")

    check(
        "adjusted p is capped at 1",
        fdr_adjusted_pvalue(0.1, 100000)["fdr_adjusted_p"] == 1.0,
    )
    check(
        "sign handled via abs",
        fdr_adjusted_pvalue(-3.5, 1)["raw_p"] == fdr_adjusted_pvalue(3.5, 1)["raw_p"],
    )


# ── momentum crash overlay [DM16] ───────────────────────────────────────────


def test_momentum() -> None:
    print("\n[momentum crash overlay - Daniel & Moskowitz 2016]")
    calm = momentum_crash_risk(0.2, 0.2)
    check("calm => NORMAL", calm["risk_level"] == "NORMAL", f"{calm['risk_level']}")
    check("calm => hold", "Within historical" in calm["action"], calm["action"])
    hot = momentum_crash_risk(0.95, 0.95)
    check(
        "crowded+stressed => SEVERE", hot["risk_level"] == "SEVERE", hot["risk_level"]
    )
    check("exposes worst months", len(hot["worst_months_on_record"]) == 3)
    check(
        "worst month is Aug 1932",
        hot["worst_months_on_record"][0]["month"] == "1932-08",
        f"{hot['worst_months_on_record'][0]}",
    )
    check(
        "worst month return is -78.96%",
        close(hot["worst_months_on_record"][0]["winner_return"], -0.7896, 1e-6),
    )
    check(
        "either flag => ELEVATED",
        momentum_crash_risk(0.9, 0.1)["risk_level"] == "ELEVATED",
    )


# ── composite autopsy ───────────────────────────────────────────────────────


def test_autopsy() -> None:
    print("\n[composite autopsy]")
    # Overfit garbage: huge backtest, 400 trials, nothing live.
    junk = autopsy(
        "RockBand Factor",
        sharpe_ratio=0.65,
        n_trials=400,
        n_obs=300,
        backtest_excess_bps=900,
        live_excess_bps=40,
    )
    check("junk is REJECT", junk["severity"] == "high", f"{junk['severity']}")
    check(
        "junk verdict is REJECT",
        junk["verdict"].startswith("REJECT"),
        junk["verdict"][:70],
    )
    check("junk lists reasons", len(junk["reasons"]) >= 2, f"{junk['reasons']}")
    check(
        "decay computed",
        junk["decay"]["decay_bps"] == 860,
        f"{junk['decay']['decay_bps']}",
    )
    check(
        "decay cites the 26/58 benchmarks",
        junk["decay"]["expected_post_publication_penalty_pct"] == 58,
    )

    # Honest, surviving signal: few trials, long sample, small decay.
    good = autopsy(
        "Momentum (India)",
        sharpe_ratio=1.1,
        n_trials=3,
        n_obs=5000,
        backtest_excess_bps=400,
        live_excess_bps=380,
    )
    check("good signal PASSES", good["severity"] == "low", f"{good['severity']}")
    check("good signal has no reasons", good["reasons"] == [], f"{good['reasons']}")
    check("MinBTL satisfied", good["min_backtest_length"]["sufficient"] is True)

    # Real effect, half decayed, weak t-stat => WARN not REJECT.
    # 50% decay is AMBER, not red: McLean & Pontiff put the expected
    # post-publication decay at 58%, so rejecting at 50% would reject the
    # median legitimate signal.
    mid = autopsy(
        "Value",
        sharpe_ratio=0.9,
        n_trials=8,
        n_obs=3000,
        backtest_excess_bps=500,
        live_excess_bps=250,
        t_stat=2.2,
        n_tests=250,
    )
    check("mid signal is WARN", mid["severity"] == "medium", f"{mid['severity']}")
    check(
        "mid signal not REJECT",
        not mid["verdict"].startswith("REJECT"),
        mid["verdict"][:60],
    )
    check("FDR block present", mid["fdr"] is not None)
    check("exactly one red flag on mid", mid["red_flags"] == 1, f"{mid['red_flags']}")
    check(
        "mid raises amber decay flag", mid["amber_flags"] >= 1, f"{mid['amber_flags']}"
    )
    check(
        "mid clears DSR",
        mid["deflated_sharpe"]["indistinguishable_from_luck"] is False,
        f"{mid['deflated_sharpe']}",
    )
    check(
        "mid clears MinBTL",
        mid["min_backtest_length"]["sufficient"] is True,
        f"{mid['min_backtest_length']}",
    )

    # too-short backtest must be caught, by name
    short = autopsy(
        "New Hot Idea",
        sharpe_ratio=1.4,
        n_trials=50,
        n_obs=400,
        backtest_excess_bps=1200,
        live_excess_bps=1100,
    )
    check(
        "short backtest flagged via MinBTL",
        any("MinBTL" in r for r in short["reasons"]),
        f"{short['reasons']}",
    )

    # ── non-normality must reach the verdict ────────────────────────────────
    # Skew/kurtosis used to be silently dropped, which is the one thing PSR
    # exists to correct for. Same headline Sharpe, fatter tails => less
    # confidence, never more.
    base = dict(
        name="Fat Tail Test",
        sharpe_ratio=1.0,
        n_trials=10,
        n_obs=1000,
        backtest_excess_bps=500,
        live_excess_bps=480,
    )
    normal = autopsy(**base, skew=0.0, kurt=3.0)
    fat = autopsy(**base, skew=-1.5, kurt=12.0)
    check(
        "fat tails lower DSR at equal Sharpe",
        fat["deflated_sharpe"]["dsr"] < normal["deflated_sharpe"]["dsr"],
        f"normal {normal['deflated_sharpe']['dsr']} vs fat "
        f"{fat['deflated_sharpe']['dsr']}",
    )
    check(
        "autopsy echoes the skew it was given",
        fat["deflated_sharpe"]["skew"] == -1.5
        and fat["deflated_sharpe"]["kurtosis"] == 12.0,
        f"{fat['deflated_sharpe']}",
    )
    order = ["high", "medium", "low"]
    check(
        "fat tails never improve severity",
        order.index(fat["severity"]) >= order.index(normal["severity"]),
        f"normal {normal['severity']} vs fat {fat['severity']}",
    )
    # extreme non-normality must not blow up or divide by zero
    wild = autopsy(**base, skew=-3.0, kurt=40.0)
    check(
        "pathological tails stay finite",
        0.0 <= wild["deflated_sharpe"]["dsr"] <= 1.0,
        f"{wild['deflated_sharpe']['dsr']}",
    )


# ── runner ──────────────────────────────────────────────────────────────────


def main() -> int:
    print("=" * 68)
    print("OMNIVEST forensics test suite")
    print("=" * 68)
    for fn in (
        test_norm,
        test_stats,
        test_frontier,
        test_psr_dsr,
        test_pbo,
        test_pbo_rank_last,
        test_minbtl,
        test_fdr,
        test_momentum,
        test_autopsy,
    ):
        fn()
    print("\n" + "=" * 68)
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} of {PASSED + len(FAILURES)}")
        for f in FAILURES:
            print(f"  - {f}")
        return 1
    print(f"ALL {PASSED} CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
