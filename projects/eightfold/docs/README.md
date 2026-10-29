# Eightfold — documentation index

Every document in this project, and which one is authoritative when they disagree.

| Document | What it covers | Authority |
|---|---|---|
| [`../README.md`](../README.md) | Entry point for a human: what this is, what state it is in | — |
| [`../PLAN.md`](../PLAN.md) | **The plan of record.** Hardware constraints, four decisions, three product pillars, milestones M0–M6, legal posture, risks | **authoritative on design and scope** |
| [`../AGENTS.md`](../AGENTS.md) | Agent instructions: identity, scope, locked decisions, traps, commands | **authoritative on how to work here** |
| [`../STATE.md`](../STATE.md) | What is verified to work, against which commit, produced by which command | **authoritative on build status** |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Append-only history of changes | — |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | How: repository layout, service model, thread model, facade, governor, profile schema, build, testing | subordinate to `PLAN.md` — it may not contradict it |
| [`RESEARCH.md`](RESEARCH.md) | What was checked, when, from where — and which beliefs are still unverified | **authoritative on evidence**; `PLAN.md` cites it |

## Reading order

1. `README.md` — the one-screen version.
2. `PLAN.md` §0 and §1 — the decisions, and the hardware that forced them.
3. `RESEARCH.md` §2 and §3 — why the mobile layer is the product.
4. `PLAN.md` §11 — the milestones, and the fact that M0 can end the project.
5. `ARCHITECTURE.md` — only once you are implementing.

## Where the numbers live

Any performance figure in any document must trace to `RESEARCH.md` (external) or to
a committed benchmark result (ours). When the two disagree, ours wins and the
external claim gets an explanatory note. Today there are **no benchmark results** —
this project has never been built.
