# ergobars

Tiny static download site for the ErgoBars WoW addon alpha: an `index.html`
plus addon `.zip`s, served by nginx and exposed publicly through the shared
Cloudflare tunnel (`gitops/core/cloudflare-tunnel`), gated by Cloudflare
Access.

- `nginx` (`nginxinc/nginx-unprivileged:1.27-alpine`, uid 101, read-only
  rootfs) serves the `ergobars-site` PVC read-only. `index.html` is sent with
  `Cache-Control: no-cache`; `*.zip` with `Content-Disposition: attachment`.
  `/healthz` backs the probes.
- `uploader` (busybox, same uid) idles with the same PVC mounted read-write at
  `/srv/site`. It is the only writer and exists so publishing is a plain
  `kubectl cp`.
- Ingress is locked to the cloudflared pods; egress is DNS only.

## Publish

Site content is not in git. From the directory holding the built site:

```sh
POD=$(kubectl -n ergobars get pod -l app=ergobars-site -o name | head -1)
kubectl -n ergobars cp dist/site/. "${POD#pod/}":/srv/site -c uploader
```

`kubectl cp` adds/overwrites but never deletes; to drop old zips:
`kubectl -n ergobars exec "${POD#pod/}" -c uploader -- rm /srv/site/<old>.zip`.

## Manual Cloudflare steps (one-time)

The tunnel is token-managed, so hostnames live in the dashboard, not here.

1. Zero Trust > Networks > Tunnels > `phillips-homelab-public` > Public
   hostname > Add: hostname `ergobars.com` (and/or `alpha.ergobars.com`),
   service `HTTP` `ergobars-site.ergobars.svc.cluster.local:80`.
2. Zero Trust > Access > Applications > Add > Self-hosted: domain
   `ergobars.com` (plus any subdomain from step 1), policy action Allow,
   Include > Emails: the tester addresses. Login method: One-time PIN.
