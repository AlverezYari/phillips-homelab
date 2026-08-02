# SPEC — webapp-scope-create-400: adding a scope fails, and lies about why

Repo: `loop-bot/tychofleet`. Gate: `make build test lint`.

Two bugs, live in production right now. The founder hit them within a
minute of trying the flow.

## 1. Adding a scope is broken: a type mismatch on the wire

`POST /v1/scopes` sends the member id as a **JSON number**, because the
site's member ids are SQLite integers:

```ts
expect(JSON.parse(init.body)).toEqual({ owner_member_id: 7, label: "Backyard S30" });
//                                                       ^ number
```

The gateway declares that field as a **string**
(`OwnerMemberID string \`json:"owner_member_id"\``), so it rejects the
request outright. Reproduced against the live gateway:

```
{"owner_member_id":7,...}    -> 400  invalid JSON body: json: cannot unmarshal
                                     number into Go struct field
                                     .owner_member_id of type string
{"owner_member_id":"7",...}  -> 201  {"scope_id":"scp_0b0e9ffa"}
```

**Fix it on this side: send a string.** The gateway stores
`owner_member_id` as `TEXT` and treats it as an opaque owner handle, so
a string is the correct representation and the gateway is not wrong
here. Do not ask for a gateway change.

Audit **every** field this repo sends to or reads from the gateway for
the same class of mismatch — not just this one call. `GET
/v1/scopes?owner_member_id=…` already stringifies via the query string
and works, which is exactly why this went unnoticed: one call site
converted implicitly and the other did not.

## 2. The error message blamed the network for a rejected request

The site rendered:

> Couldn't reach the scope service — try again shortly.

It reached the scope service perfectly. The service replied 400. Its
own log line even had it right — `gateway: POST /v1/scopes returned
400, expected 201` — while the user-facing text sent someone off to
check DNS and firewalls for a request-shape bug.

**"Unreachable" and "rejected" are different facts and must read
differently.** This is the same failure this project keeps repeating:
one state wearing another state's clothes.

- A transport failure (DNS, refused, timeout, network policy) is the
  only thing allowed to say the service could not be reached.
- A response that arrives and is not what we wanted says so: the
  request was rejected, and — for a 4xx that indicates our own bug —
  says plainly that something is wrong on our side rather than
  suggesting the user retry. Retrying a 400 never helps.
- A 5xx may reasonably suggest trying again.

Audit every gateway call site in the repo for this conflation, not only
scope creation. Put the list in PR.md: call site, what it said before,
what it says now.

## Tests

- [ ] The create-scope request body carries `owner_member_id` as a
  **string**, asserted on the serialised body.
- [ ] A test that would have caught this: feed the client a gateway stub
  that validates types the way the real gateway does (reject a number),
  and assert the call succeeds. A stub that accepts anything is how a
  green suite shipped a broken flow.
- [ ] A 400 from the gateway renders as a rejection, not as
  unreachable, and does not tell the user to try again shortly.
- [ ] A genuine transport failure still renders as unreachable.
- [ ] Every other gateway field is exercised with the type the gateway
  actually declares.

## Warts / traps

- Do not change the gateway, its API shape, or anything in the tycho
  repo. This is a client-side fix.
- Do not weaken the gateway stub to make tests pass. The stub being too
  permissive is the root cause of this reaching production.
- The enrolment flow, download route, session gate and scope UI all
  shipped today and are verified working — this loop touches the
  request body and the error text, nothing else.
- Leftover test scopes exist in the catalog from debugging
  (`Numeric Test`, `String Test`, owner `7`, plus `flowtest-member`).
  Ignore them; do not write cleanup code.

Finish: `/workspace/PR.md` with the corrected request body, the full
audit table of gateway call sites and their old/new error text, and the
test that fails against the old code.
