# ergobars

Download site for the ErgoBars WoW addon alpha (an `index.html` plus addon
`.zip`s) and its feedback board, served by nginx and exposed publicly through
the shared Cloudflare tunnel (`gitops/core/cloudflare-tunnel`) at
https://ergobars.com. Public, no login.

- `nginx` (`nginxinc/nginx-unprivileged:1.27-alpine`, uid 101, read-only
  rootfs) serves the `ergobars-site` PVC read-only. `index.html` is sent with
  `Cache-Control: no-cache`; `*.zip` with `Content-Disposition: attachment`.
  `/healthz` backs the probes.
- `uploader` (busybox, same uid) idles with the same PVC mounted read-write at
  `/srv/site`. It is the only writer and exists so publishing is a plain
  `kubectl cp`.
- nginx proxies `/board`, `/board/*` (incl. `/board/static`) and `/api/*` to
  the board (below). Everything else is the static site.
- Ingress is locked to the cloudflared pods (plus the board, for the version
  list); egress is DNS and the board.

## Feedback board

`ergobars-board` (`board-*.yaml`): FastAPI + SQLite feedback board with Jev
triage (TypeSafe). Source and full docs: `cachyos-setup/ergodox/board/`.

- Image `zot.phillips-homelab.net/ergobars:board-<sha>` (anonymous pull, like
  the other zot apps), uid 10001, read-only rootfs, `/tmp` emptyDir.
- Database `/data/board.db` on the `ergobars-board-data` PVC (1Gi, RWO, so
  one replica and `Recreate`).
- Reached only through the site nginx. nginx sets `X-Forwarded-For` (and
  `X-Real-IP`) to Cloudflare's `CF-Connecting-IP`, overwriting whatever the
  client sent; the board (`BOARD_TRUST_PROXY=1`) takes the rightmost XFF entry
  as the client address and stores only a salted hash of it (rate limits).
- Addon versions for the report form come from the download page
  (`BOARD_SITE_URL` = the in-cluster site Service), falling back to
  `board.toml`.
- Egress: DNS, the site, and 443 to `api.typesafe.ai` and
  `challenges.cloudflare.com` only (toFQDNs, DNS proxy enabled for this pod
  alone, as in tychofleet).

### Secrets (1Password item `ergobars`)

Synced by `board-external-secret.yaml` into Secret `ergobars-board`:

| 1Password field     | Env var             | Notes |
|---------------------|---------------------|-------|
| `typesafe-api-key`  | `TYPESAFE_API_KEY`  | Jev key. |
| `board-admin-token` | `BOARD_ADMIN_TOKEN` | Maintainer token: a long random string (`openssl rand -hex 32`). **Add it before the first sync**, or the ExternalSecret errors and the pod waits on the missing Secret. |
| `turnstile-secret`  | `TURNSTILE_SECRET`  | Not used yet (phase 2 captcha). |

`BOARD_SECRET` (hash/CSRF salt) is left unset: the app generates one and keeps
it in the db. Env is read at start, so after changing a field:
`kubectl -n ergobars rollout restart deploy/ergobars-board` (after ESO's 1h
refresh, or force it by annotating the ExternalSecret).

### Maintainer access

Open `https://ergobars.com/board/admin?token=<board-admin-token>` once; it
sets a 30-day cookie and redirects the token out of the URL. Log out at
`/board/admin/logout`.

### New board image

Build and push `zot.phillips-homelab.net/ergobars:board-<sha>` from
`cachyos-setup/ergodox/board/`, then bump the tag in `board-deployment.yaml`
and merge; Argo rolls it (Recreate: a few seconds of 502 on `/board`).

### nginx config changes

nginx does not reload a changed ConfigMap. Bump the
`ergobars.com/nginx-conf-rev` annotation in `deployment.yaml` with every
`configmap.yaml` edit so the site pod is rolled.

## Publish

Site content is not in git. From the directory holding the built site:

```sh
POD=$(kubectl -n ergobars get pod -l app=ergobars-site -o name | head -1)
kubectl -n ergobars cp dist/site/. "${POD#pod/}":/srv/site -c uploader
```

`kubectl cp` adds/overwrites but never deletes; to drop old zips:
`kubectl -n ergobars exec "${POD#pod/}" -c uploader -- rm /srv/site/<old>.zip`.

## Manual Cloudflare step (one-time)

The tunnel is token-managed, so hostnames live in the dashboard, not here.
Zero Trust > Networks > Tunnels > `phillips-homelab-public` > Public hostname
> Add: hostname `ergobars.com`, service `HTTP`
`ergobars-site.ergobars.svc.cluster.local:80`. The site is public: no
Cloudflare Access application. The board needs no hostname of its own (it
sits behind nginx).
