# Decisions

Every judgement call made during the overnight restyle run, with reasoning.
Newest at the bottom.

## D0 — Branches (2026-10-05, fire-cd6e6b)

The cloud harness that started this fire assigned it the branch
`second/gracious-cannon-1eynaf`; the stored prompt names
`design-exploration-restyle` (phases 0–7) and `restyle-implementation`
(phase 8). The prompt's branches win, because the next three fires are fresh
sessions that will look for `design-exploration-restyle` on `origin`, and a
run split across per-fire branch names would lose its ledger. Every push of
the exploration branch is also mirrored to the harness's branch, so nothing
is only on a branch the harness did not name. Neither is ever merged to
`main`, and no pull request is opened.
