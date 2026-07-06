# SPEC: smoke — hello-world Go service

A trivial spec to exercise the full loop lifecycle: iterate, gate, push,
decision queue, done sentinel.

## Requirements

- [ ] Initialize a Go module `code.phillips-homelab.net/loop-bot/smoke` with a
      `main.go` that prints `hello from the loop rig` and exits 0.
- [ ] Add a `Makefile` with `build`, `test`, `lint` targets (`lint` may be
      `go vet ./...`). All three must pass.
- [ ] Add a unit test for the greeting string (extract it to a function).
- [ ] DECISION EXERCISE: write a decision file asking whether the greeting
      should include an exclamation mark. Do NOT resolve this yourself: file
      the decision, treat this item as BLOCKED until an answer appears in
      /workspace/.inbox/, then apply the answer.

## Validation gates (harness-enforced)

`make build test lint` green in /workspace/repo.

## Guardrails

- Max 3 attempts per item, then BLOCKED + decision file + move on.
- No secrets in code, logs, or commits.
- Completion: all boxes checked, gates green -> write /workspace/.loop-done.
