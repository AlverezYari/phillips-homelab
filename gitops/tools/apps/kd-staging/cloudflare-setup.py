"""Publishes the kd-staging hostnames on the personal Cloudflare tunnel, behind one Access app.

Idempotent; safe to re-run. Order matters: the Access apps (email allowlist) are created or updated FIRST, so a
hostname is never routed without Access in front of it. Then the tunnel's ingress list gets the kd-* entries
(every other entry, including miso-lab and the catch-all, is kept as is), then the proxied DNS CNAMEs.

Env: CF_API_TOKEN, ACCESS_EMAILS (comma separated). Prints no secrets.
"""
import json
import os
import sys
import urllib.error
import urllib.request

ZONE = "phillips-homelab.net"
API = "https://api.cloudflare.com/client/v4"
APP_NAME = "kd-staging"
# The personal tunnel is the one already serving this host (see cloudflare-tunnel-personal/deployment.yaml).
TUNNEL_MARKER = "miso-lab.phillips-homelab.net"
SVC = "kd-staging.svc.cluster.local"
ROUTES = [
    {"hostname": "kd-staging." + ZONE, "service": f"https://kd.{SVC}:8443",
     "originRequest": {"originServerName": "kd-staging." + ZONE}},
    {"hostname": "kd-grafana." + ZONE, "service": f"http://grafana.{SVC}:3000"},
    {"hostname": "kd-git." + ZONE, "service": f"http://gitea.{SVC}:3000"},
    {"hostname": "kd-whoami." + ZONE, "service": f"http://oauth2-proxy.{SVC}:4180"},
]
HOSTS = [r["hostname"] for r in ROUTES]
TOKEN = os.environ["CF_API_TOKEN"].strip()
EMAILS = [e.strip() for e in os.environ["ACCESS_EMAILS"].split(",") if e.strip()]


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=None if body is None else json.dumps(body).encode(),
                                 headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            out = json.load(r)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        sys.exit(f"cloudflare: {method} {path} -> {e.code}: {detail}")
    if not out.get("success", False):
        sys.exit(f"cloudflare: {method} {path} failed: {out.get('errors')}")
    return out["result"]


def main():
    if not EMAILS or not all("@" in e for e in EMAILS):
        sys.exit("cloudflare: ACCESS_EMAILS must hold at least one email; refusing to publish without Access")
    zones = call("GET", f"/zones?name={ZONE}")
    if not zones:
        sys.exit(f"cloudflare: zone {ZONE} not visible to this token")
    zone_id, acct = zones[0]["id"], zones[0]["account"]["id"]
    print(f"zone {ZONE}, {len(EMAILS)} allowed email(s)")

    # 1. Access: one zone-level self-hosted app per kd-* host, each with its own allow policy (the email list).
    # Zone-scoped on purpose: the token has the zone-level "Access: Apps and Policies" permission; account-level
    # reusable policies would need the separate account permission "Access: Policies".
    include = [{"email": {"email": e}} for e in EMAILS]
    existing = {a.get("name"): a for a in call("GET", f"/zones/{zone_id}/access/apps")}
    for h in HOSTS:
        name = f"{APP_NAME} {h.split('.')[0]}"
        app = {"name": name, "type": "self_hosted", "domain": h, "session_duration": "24h",
               "app_launcher_visible": False}
        if name in existing:
            app_id = existing[name]["id"]
            call("PUT", f"/zones/{zone_id}/access/apps/{app_id}", app)
        else:
            app_id = call("POST", f"/zones/{zone_id}/access/apps", app)["id"]
        policy = {"name": "allow listed emails", "decision": "allow", "include": include, "precedence": 1}
        have = call("GET", f"/zones/{zone_id}/access/apps/{app_id}/policies")
        if have:
            call("PUT", f"/zones/{zone_id}/access/apps/{app_id}/policies/{have[0]['id']}", policy)
        else:
            call("POST", f"/zones/{zone_id}/access/apps/{app_id}/policies", policy)
    print(f"access: {len(HOSTS)} zone apps, each allowing the listed emails")

    # 2. Tunnel ingress: replace only the kd-* rules, keep everything else and the catch-all last.
    tunnel = None
    for t in call("GET", f"/accounts/{acct}/cfd_tunnel?is_deleted=false"):
        cfg = call("GET", f"/accounts/{acct}/cfd_tunnel/{t['id']}/configurations")
        ingress = ((cfg or {}).get("config") or {}).get("ingress") or []
        if any(r.get("hostname") == TUNNEL_MARKER for r in ingress):
            tunnel = (t, cfg["config"], ingress)
            break
    if tunnel is None:
        sys.exit(f"cloudflare: no tunnel routes {TUNNEL_MARKER}; not guessing which tunnel to change")
    t, config, ingress = tunnel
    kept = [r for r in ingress if r.get("hostname") not in HOSTS]
    named = [r for r in kept if r.get("hostname")]
    catch_all = [r for r in kept if not r.get("hostname")] or [{"service": "http_status:404"}]
    config = dict(config, ingress=named + ROUTES + catch_all[-1:])
    call("PUT", f"/accounts/{acct}/cfd_tunnel/{t['id']}/configurations", {"config": config})
    print(f"tunnel {t['name']}: {len(named)} other route(s) kept, {len(ROUTES)} kd-* route(s) set")

    # 3. DNS: proxied CNAMEs to the tunnel.
    target = f"{t['id']}.cfargotunnel.com"
    for h in HOSTS:
        rec = {"type": "CNAME", "name": h, "content": target, "proxied": True, "comment": "kd-staging (gitops)"}
        have = call("GET", f"/zones/{zone_id}/dns_records?name={h}")
        if have:
            if have[0]["type"] != "CNAME":
                sys.exit(f"cloudflare: {h} already has a {have[0]['type']} record; not replacing it")
            call("PUT", f"/zones/{zone_id}/dns_records/{have[0]['id']}", rec)
        else:
            call("POST", f"/zones/{zone_id}/dns_records", rec)
    print(f"dns: {len(HOSTS)} CNAMEs -> tunnel")


main()
