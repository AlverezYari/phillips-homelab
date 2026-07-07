# SPEC: ghmon4 — API rate-limit citizenship, fourth loop

Continuing the same project as loops 1–3 (merged as PRs #1–#3). Read
`CLAUDE.md` (authoritative) and `gh-working-man.md` (handoff) in the repo
before item 1. Do not regress anything live on main (M1–M8, tests, theme
system, flex columns, org fan-out, stats view, per-job rerun).

Field incident driving this loop: the app exhausted GitHub's 5,000 req/hr
REST budget in real use. Baseline load is ~11k req/hr (three org fan-out
sections × ~30 repos × 30s refresh), and opening the stats view fires
windowed ListRuns across every fan-out repo — it burned ~4,900 requests in
seconds. Result: every section 403s ("API rate limit exceeded"), which the
UI shows as "retrying" — and retrying makes it worse. This loop makes the
app fit comfortably inside the budget and behave sanely when it's spent.

## Requirements

- [ ] Conditional requests: send If-None-Match with cached ETags on every
      runs/repos GET; on 304, serve the cached body (304s cost ZERO rate
      limit). In-memory cache keyed by full request URL is sufficient.
      Mock-test: 200-with-ETag → 304 serves cache; changed ETag replaces
      the entry.
- [ ] Rate-limit state tracking: parse X-RateLimit-Remaining/-Reset from
      every response into a shared budget tracker. When remaining is
      below a floor (e.g. 100), suspend all polling until reset and mark
      sections "rate limited — resumes HH:MM" — a DISTINCT error class
      and UI state from transient "retrying" (a 403 rate-limit response
      must never be classified as retryable). Unit-test the tracker and
      the classification as pure functions.
- [ ] Shared org repo-list cache: org sections currently re-list the
      org's repos every refresh. One shared cache (TTL ~15 min) across
      all sections per org. Mock-test: two sections, one org, one
      list-repos call.
- [ ] Stats view budget discipline: cache fetched window data per
      (section, window) — cycling `w` or reopening stats must NOT
      refetch within a TTL (~10 min); cap pagination per repo (e.g. 3
      pages) and surface "capped at N runs" in the view rather than
      silently fetching everything. Mock-test cache hits and the cap.
- [ ] Refresh cadence by section type: single-repo sections keep 30s;
      org fan-out sections default to 3 min, staggered so sections do
      not fire in the same instant. Both intervals config-overridable.
      Unit-test the schedule/stagger computation.
- [ ] Fan-out observability: per-repo fan-out failures are currently
      invisible (only an aggregate warning count). Log each failing repo
      + error class at WARN via the existing slog setup, and show the
      per-repo error class in the section warning line (e.g. "2 rate
      limited, 1 not found"). Extend existing fan-out tests.

## Validation gates (harness-enforced)

`make build test lint` — green, offline, no gh auth (mocks only). All new
behavior must be testable against the existing mocked go-gh transport —
no real GitHub calls anywhere, including in manual verification.

## Guardrails

- Repo conventions per CLAUDE.md: conventional commits, one logical change
  per commit, each commit builds. Commit your own work; the harness pushes.
- Known warts (gh-working-man.md): bubbles/table ANSI padding, lipgloss
  Width() word-wrap, submodel pointer re-sync.
- Never run the TUI in tests; pure logic and api layer only.
- Max 3 distinct attempts per item, then BLOCKED + decision file, move on.
- Judgment calls: simplest reading of CLAUDE.md; decisions only if
  genuinely ambiguous AND consequential. Cache TTLs, the remaining-budget
  floor, and page caps are operator-tunable details — pick the SPEC's
  suggested values, make them config-overridable where cheap, do not file
  decisions over them.
- No secrets in code/logs/commits. Only the origin remote.
- All done + green -> /workspace/.loop-done AND /workspace/PR.md (reviewer-
  facing: what changed / how verified / review notes). All remaining
  blocked -> /workspace/.loop-blocked.
