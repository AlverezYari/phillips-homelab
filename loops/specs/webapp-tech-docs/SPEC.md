# SPEC — webapp-tech-docs: explain the machine to someone who might join it

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

## Why

Tycho now does something worth explaining: a telescope in a back garden
attests its own identity, joins a private tailnet in-process, streams
frames to a gateway that authenticates every request per-scope, and its
photons get pooled with strangers' into a shared master with honest
per-source attribution.

None of that is written down anywhere a visitor can read. `docs/`
exists on the site but predates all of it.

The audience is **an amateur astronomer with a Seestar who is deciding
whether to trust this with their nights** — technically literate,
not a distributed-systems engineer. Second audience: someone
considering contributing.

## What to build

Technical documentation under the site's existing `docs/` section.
Suggested shape, argue for a different one if it's better:

1. **How Tycho works** — the whole pipeline in one page. Scope → client
   → gateway → object storage + catalog → combine → pooled master →
   attribution. A diagram if you can make one that survives dark mode.
2. **What runs on your machine** — the client. What it does, what it
   talks to, what it stores. Explicitly: it needs a computer beside the
   scope that stays awake.
3. **Identity and trust** — how a scope proves what it is, what a
   per-scope credential is, what the fleet tailnet does and does not
   give other people access to. This is the section that earns trust or
   loses it.
4. **Attribution** — how seconds are counted, why it's `SUM` over
   sessions of `MAX(totalexp_s)` rather than a flat sum, and why nobody
   gets a byline.

## The rules that matter

**Every claim must be true today.** Not aspirational, not "will soon".
If something is designed but unbuilt, either omit it or say plainly
that it isn't built. This project has just spent two days finding
comments that asserted properties the code didn't have; documentation
that does the same to *members* is worse.

**Be specific where specificity builds trust.** "Your scope can reach
the gateway and nothing else on the network" is worth more than "we
take security seriously" — and it's checkable.

**Do not overclaim on security.** Device attestation is
**self-reported, not cryptographic**: a modified firmware can report
any serial. Say so. The per-scope credential is real authentication;
the attestation is a consistency signal. Anyone who reads the ADRs and
then the docs must not find the docs flattering.

**Source of truth:** `docs/adr/0008-scope-identity.md` and
`0009-scope-credentials.md` in the **tycho** repo, plus what is actually
deployed. Where an ADR and reality disagree, reality wins and the ADR
gets an issue, not a quiet paper-over.

## Design

The existing `docs/` pages are the largest surviving pre-redesign
surface — `text-slate-*` throughout, while newer pages use the bespoke
tokens. **Do not deepen that split.** Use the current design tokens for
anything new. If that makes new pages clash with old ones, say so in
PR.md rather than compromising toward the old style; unifying is
tracked separately.

Accessibility, since these are read-heavy pages: real headings in
order, `<h1>` per page, no reliance on `--color-text-faint` for
anything load-bearing (it fails WCAG AA — tracked separately), and
tables with `scope="col"` if you use any.

## Tests

- [ ] Every new page renders and is reachable from the docs index and
  from the nav — this repo has shipped links to routes nobody built.
- [ ] The existing link-integrity crawl covers them. Note that
  `crawl.test.ts` currently generates its cases from `dist/` and, with
  everything SSR, produces **one** test — if that's still true, say so
  in PR.md rather than assuming coverage.
- [ ] No page claims a capability that does not exist. List in PR.md
  every factual claim you made about identity, security or attribution,
  with the file that backs it.

## Warts / traps

- Do not change enrolment, the scope API, the download route, key
  minting or authorization — all shipped and verified against the live
  gateway.
- Do not document `PROGRESS.md`, `SPEC.md` or loop-rig internals.
  Members do not care and those files are not public.
- `docs/design/**` is read-only law.

Finish: `/workspace/PR.md` with an ASCII render of each page, the table
of claims and their backing files, and anything you deliberately left
out because it isn't built yet.
