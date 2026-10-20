# kd-staging

A kd staging server and three demo apps that sign in through it, for testing with outside friends.
Nothing here touches the rest of the homelab: own namespace, own volumes, ingress only from the personal
Cloudflare tunnel.

| Host | What |
|---|---|
| kd-staging.phillips-homelab.net | kd (console at /admin, self-service at /me/) |
| kd-grafana.phillips-homelab.net | Grafana; role from kd groups (admins, editors) |
| kd-git.phillips-homelab.net | Gitea; kd is the only sign-in; admins group = Gitea admin |
| kd-whoami.phillips-homelab.net | whoami behind oauth2-proxy; only the editors group gets in |

All four sit behind Cloudflare Access (one zone-level app per host, named `kd-staging <host>`), whose allowlist is the `access-emails` field of
the 1Password item `kd-staging-cloudflare`. The `cloudflare-setup` job (re-runs about daily) publishes the hosts:
Access first, then the tunnel routes (other routes kept), then the DNS CNAMEs. Edit the emails in 1Password,
they apply on the next daily run, or delete the job to run it now.

Sign-in is the email code (one-time PIN) only: the apps allow just that login and go straight to it, because
the "Cloudflare" login is limited to members of this Cloudflare account and outside friends hit "Cloudflare
sign-in is restricted to members of the account". The job's token needs the account permission
"Access: Organizations, Identity Providers, and Groups Read" to find the one-time PIN login; without it the job
stops before changing anything.

- **Certificate:** cert-manager `kd-staging-tls` (Let's Encrypt) from the namespace issuer `kd-staging-letsencrypt`, which uses this app's own Cloudflare token for DNS-01; kd reloads it on renewal.
- **Back-channel:** the demo apps map kd-staging.phillips-homelab.net to kd's pinned ClusterIP
  (10.100.77.10) with hostAliases, so their token/userinfo calls never go through Access.
- **Config:** `kd.toml` is a seed copied to the volume on first start only; the console owns it after.
- **Secrets:** OIDC client secrets and the oauth2-proxy cookie secret are generated in-cluster once.
- **Remove:** delete the Argo app, then remove the four hostnames, the DNS records and the Access app in
  Cloudflare (or run the job's inverse), and the volumes' LUNs (`scripts/synology-luns.py`).
