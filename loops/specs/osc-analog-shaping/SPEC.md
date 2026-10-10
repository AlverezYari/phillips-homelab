# SPEC — osc-analog-shaping: deadzone, curves, sensitivity, speed (wave 3, ungated)

Repo: `loop-bot/OpenSteamController`. Gate: `make build test lint`.
Image: rust-2.

**Read first, all on main:** `CLAUDE.md`;
`docs/design/motion-and-feedback.md` **v4 §3** — law with GO from
sol-review-osc-wave34 round 3. The §3.2 golden vectors are
Sol-verified numbers: they become tests VERBATIM.

## Build, in order (red-first per item)

1. - [ ] **Vocabulary**: the seven §3.1 keys on their admitted
   behaviors only (eligibility matrix as validation — wrong-behavior
   key errors name key and behavior), finiteness rejection, curve
   law (4 points, strictly increasing in, in[0]=0, in[3]=1, out
   non-decreasing in [0,1], out[0]=0, out[3]=1).
2. - [ ] **Same-commit schema amendments**: the shaping rows join
   timing-engine §3's schema-2 trigger list and config-profiles §3's
   validation rows IN YOUR COMMIT (edit the design docs — the
   amended-in-this-commit rule; PR.md quotes the diff hunks).
3. - [ ] **Position-class transform** (§3.2 steps 1–6): pure
   function, golden vectors verbatim plus the custom-curve and
   normalization vectors, corner totality (|n| > 1), zero-vector
   branch order.
4. - [ ] **Rate-class law**: shaped vector for stick mouse/scroll
   (zero inside deadzone, u × m₁ outside), delta inversion, `speed`
   multiplying the existing constants (constants become documented
   defaults) — existing fractional accumulation untouched.
5. - [ ] **Editor**: per-behavior "Tuning" disclosure row, numeric
   fields only (validated ranges live), §14.1 preservation
   red-first, schema-2 upgrade prompt integration, preview tour
   steps.

## Warts / traps

- A single `Instant::now()` in osc-config is a spec violation
  (injected values only — shaping is pure math anyway).
- Reader matrix per §3.3: older readers give the ORDINARY
  unknown-key diagnostic — do not invent "too old" wording.
- Triggers admit nothing; §14.4 untouched.
- No new crates. PR.md to /workspace/PR.md.

## Finish — PR.md
Golden-vector test names; the two design-doc diff hunks; eligibility
matrix audit; tour confirmation; untested-here.
