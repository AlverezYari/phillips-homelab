# SPEC — client-meteogram: a Clear Sky Chart for tycho-client

Repo: `loop-bot/tycho`. Gate: `make build test lint`.

**Read first, both are on main:**
[docs/briefs/2026-08-weather-meteogram.md](../../../docs/briefs/2026-08-weather-meteogram.md)
— Casey's brief, authoritative for intent and data sources — and
[docs/design/tycho-client/README.md](../../../docs/design/tycho-client/README.md),
the frozen design handoff.

The brief wins on intent. The design doc wins on layout law.

## Sequencing is not optional

The design README is a **frozen handoff**. Code and doc must not fork,
so the doc changes *first*, in its own commit, before any Go:

1. **Amend `docs/design/tycho-client/README.md`.** Screen 6b's single
   "Cloud cover · next 10 h" row becomes a meteogram pane. Widen the
   state model's `weather.forecast.hourly[10]` to 48, with per-row
   fields plus provenance and fetched-at. Leave the **sensors pane and
   escalation ladder untouched** — the meteogram is lookahead; sensors
   stay authoritative, per 6b's own line: *"forecasts are wrong and
   sensors are not."*
2. **Pattern kit next** (design doc §3): `meteogram(rows []MeteoRow,
   hours int, width int) string`, a sibling of the existing
   `bar(segments []Segment, width int) string` at README:175. Same
   shape of API, same file, same testing style.
3. **Providers + almanac** behind one interface.
4. **Wire into 6b** last.

A PR that implements the pane without the doc amendment is rejected
regardless of how good the pane is.

## The pane

- **48 h horizon, 1 char per hour.** Fits the 54-76 ch pane widths, and
  48 h is where these forecasts stop being trustworthy.
- **Six rows**: `cloud`, `transp`, `seeing`, `dark`, `wind`, `hum`.
  Hour ruler on top. Keep 6b's closing **usable-window sentence** —
  computed as dark AND cloud-below-threshold AND
  transparency-above-threshold.
- **Encoding: glyph height `▁▂▃▅▆▇` PLUS colour.** Height must carry
  the value on its own. This beats the original Clear Sky Chart, which
  is colour-only and colourblind-hostile — do not regress to that.
- **`seeing` is 3-hourly at source.** Render one glyph repeated across
  each 3 h block rather than interpolating; the source's own
  granularity should be visible.
- **`dark` is a locally computed almanac**, not a forecast: sun and
  moon altitude from the site's lat/long in Go. No network, never
  stale.
- **Grid rule 1 applies** (README:141): `█` U+2588 is banned — its
  advance width differs across monospace stacks, so bars change width
  as they fill. Use the sparkline family or `▮▯`.
- **Degraded state** is already specified in 6b: provider unreachable
  → forecast rows render stale-dashed, the `dark` row still renders,
  sensors unaffected, thresholds unchanged.

## Two boundaries that are not stylistic

**The meteogram is display-only.** Weather *thresholds* remain
server-declared policy (design doc open question #4). This pane
visualises the quantities the escalation ladder triggers on; it must
never become a source those decisions read from. If you find yourself
wiring meteogram output into the ladder, stop.

**Non-TTY rule.** The data lives in the model and emits on the
JSON-lines path; only `View()` draws glyphs. A headless run must
produce the same information without a single box-drawing character.

## Data sources — decided, with a prohibition

- **Open-Meteo**, `models=gem_seamless` — the same Canadian GEM family
  the real Clear Sky Chart is built on. Hourly cloud cover (total plus
  low/mid/high), wind, humidity, temp, dewpoint. Feeds `cloud`, `wind`,
  `hum`. **CC-BY: a one-line credit is required** in the pane footer or
  help overlay. Not optional, not a TODO.
- **7Timer ASTRO** — the only free source serving **seeing and
  transparency** as products. 3-hourly to 72 h. Feeds `seeing`,
  `transp`.
- **Local almanac** for `dark`, from site lat/long (already in scope
  config, design doc 5a).

**Do not scrape cleardarksky.com.** Its charts are pixel-sampled
Environment Canada map images; decoding or republishing them is against
their terms and North-America-only. This is a hard prohibition, not a
preference.

The provider interface must make **each row's source and fetch time
inspectable** — that feeds the stale rendering and the 5a "why is this
scope doing that" debugging ethos.

## Note on what already exists

The operator already polls Open-Meteo (`operator/internal/weather`,
`WEATHER_ENABLED=true`, 30 min) and writes `Seestar.status.sky`:
current cover, best hour ahead, usable flag. That is a **different
consumer** — server-side policy input, not this pane.

Do not break it, do not reuse its Poller for the client, and say in
PR.md how you decided the client fetches (directly, or via the
gateway). The client talks to the gateway over the tailnet, not the
Kubernetes API.

## Tests

- [ ] 6b renders the 6-row 48 h meteogram in the reference 112-126 ch
  terminal. Put the render in PR.md.
- [ ] It degrades at 80 ch per grid rule 5 — drop to 24 h or scroll,
  your call, but **note the decision in the doc amendment**.
- [ ] `NO_COLOR` output is fully legible from heights alone. Show it.
- [ ] Network killed: forecast rows go stale-dashed, `dark` row and
  sensors keep rendering live.
- [ ] **Recorded fixtures for both providers. No test touches a live
  API.**
- [ ] The usable-window sentence agrees with a hand-check against the
  rendered rows — show the check.
- [ ] Full gate green including `-race`, 0 skips from anything you
  touch.

## Warts / traps

- Do not touch `operator/internal/weather`, the delivery framework, or
  anything in `combine/`.
- Do not add a dependency for the almanac if the maths is a few dozen
  lines — sun/moon altitude is well-trodden and a dependency for it is
  a poor trade in a client binary users download.
- Attribution is a requirement, not a nicety.
- The design doc is law on layout. Where the brief and the doc appear
  to conflict, say so in PR.md rather than silently picking.

Finish: `/workspace/PR.md` with the reference-width render, the 80 ch
degradation, the `NO_COLOR` render, the doc amendment diff, how the
client fetches and why, and the usable-window hand-check.
