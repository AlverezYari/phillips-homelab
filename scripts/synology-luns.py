#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6"]
# ///
"""Map Synology iSCSI LUNs to Kubernetes PVs, and find orphans.

syno-iscsi-default is `reclaimPolicy: Retain`: deleting an app leaves its PV `Released` and
its LUN (with the data) on the NAS. In DSM a LUN shows a name like `k8s-csi-pvc-<uuid>`, but a
PV only records the LUN's internal uuid (`spec.csi.volumeHandle`), so the two never visibly
match. This joins them.

    scripts/synology-luns.py                     # every LUN: size, PV/PVC, status, targets
    scripts/synology-luns.py --orphans           # LUNs no PV references (+ Released PVs)
    scripts/synology-luns.py --find stock-bot    # filter on LUN name / uuid / PV / PVC
    scripts/synology-luns.py delete <lun-uuid>   # delete one orphan LUN and its target(s)

Read only unless you run `delete`, which refuses a LUN that any PV still references or that
has a connected iSCSI session, shows what it will remove, and asks you to type the LUN name.

Credentials: the CSI driver's own config, read with your kubectl from
synology-csi/client-info-secret (key client-info.yml; ESO from 1Password item
synology-csi-client-info). `--client-info FILE` reads a local copy instead. The password is
only ever sent to DSM; nothing is printed or written.
"""

import argparse
import base64
import json
import ssl
import subprocess
import sys
import urllib.parse
import urllib.request

import yaml

TIMEOUT = 20


class DSM:
    """The same SYNO.* calls the synology-csi driver makes (pkg/dsm/webapi)."""

    def __init__(self, c: dict):
        scheme = "https" if c.get("https") else "http"
        self.base = f"{scheme}://{c['host']}:{c.get('port', 5001 if c.get('https') else 5000)}/webapi"
        self.ctx = ssl._create_unverified_context() if c.get("insecureSkipVerify") else None
        self.sid = None
        r = self._call("auth.cgi", api="SYNO.API.Auth", method="login", version="3",
                       account=c["username"], passwd=c["password"], format="sid", session="synology-luns")
        self.sid = r["sid"]

    def _call(self, cgi: str, **params) -> dict:
        if self.sid:
            params["_sid"] = self.sid
        url = f"{self.base}/{cgi}?{urllib.parse.urlencode(params)}"
        with urllib.request.urlopen(url, timeout=TIMEOUT, context=self.ctx) as resp:
            body = json.loads(resp.read())
        if not body.get("success"):
            raise RuntimeError(f"{params.get('api')}.{params.get('method')}: DSM error {body.get('error')}")
        return body.get("data") or {}

    def luns(self) -> list[dict]:
        types = '["BLOCK","FILE","THIN","ADV","SINK","CINDER","CINDER_BLUN","CINDER_BLUN_THICK","BLUN","BLUN_THICK","BLUN_SINK","BLUN_THICK_SINK"]'
        return self._call("entry.cgi", api="SYNO.Core.ISCSI.LUN", method="list", version="1", types=types,
                          additional='["allocated_size","status","flashcache_status","is_action_locked"]').get("luns", [])

    def targets(self) -> list[dict]:
        return self._call("entry.cgi", api="SYNO.Core.ISCSI.Target", method="list", version="1",
                          additional='["mapped_lun","connected_sessions"]').get("targets", [])

    def delete_target(self, target_id: int) -> None:
        self._call("entry.cgi", api="SYNO.Core.ISCSI.Target", method="delete", version="1", target_id=f'"{target_id}"')

    def delete_lun(self, uuid: str) -> None:
        self._call("entry.cgi", api="SYNO.Core.ISCSI.LUN", method="delete", version="1", uuid=f'"{uuid}"')

    def logout(self) -> None:
        try:
            self._call("auth.cgi", api="SYNO.API.Auth", method="logout", version="1", session="synology-luns")
        except Exception:  # noqa: BLE001 - best effort
            pass


def kubectl_json(*args: str) -> dict:
    out = subprocess.run(["kubectl", *args, "-o", "json"], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def client_info(path: str | None, host: str | None) -> dict:
    if path:
        text = open(path).read()
    else:
        sec = kubectl_json("-n", "synology-csi", "get", "secret", "client-info-secret")
        text = base64.b64decode(sec["data"]["client-info.yml"]).decode()
    clients = yaml.safe_load(text)["clients"]
    if host:
        clients = [c for c in clients if c["host"] == host]
    if len(clients) != 1:
        sys.exit(f"expected one DSM client, found {len(clients)}; pass --host")
    return clients[0]


def pv_index() -> dict[str, dict]:
    """volumeHandle (LUN uuid) -> PV summary, for synology-csi PVs only."""
    out = {}
    for pv in kubectl_json("get", "pv")["items"]:
        csi = pv["spec"].get("csi") or {}
        if csi.get("driver") != "csi.san.synology.com":
            continue
        ref = pv["spec"].get("claimRef") or {}
        out[csi.get("volumeHandle", "")] = {
            "pv": pv["metadata"]["name"],
            "pvc": f"{ref.get('namespace', '?')}/{ref.get('name', '?')}" if ref else "-",
            "phase": pv["status"].get("phase", "?"),
            "reclaim": pv["spec"].get("persistentVolumeReclaimPolicy", "?"),
        }
    return out


def gib(n) -> str:
    return f"{int(n or 0) / 2**30:,.1f}G"


def rows(dsm: DSM):
    pvs = pv_index()
    targets = dsm.targets()
    by_lun: dict[str, list[dict]] = {}
    for t in targets:
        for m in t.get("mapped_luns") or []:
            by_lun.setdefault(m.get("lun_uuid"), []).append(t)
    for lun in dsm.luns():
        pv = pvs.get(lun["uuid"])
        state = "ORPHAN" if pv is None else ("RELEASED" if pv["phase"] == "Released" else pv["phase"].upper())
        ts = by_lun.get(lun["uuid"], [])
        yield {
            "state": state, "name": lun.get("name", ""), "uuid": lun["uuid"], "size": gib(lun.get("size")),
            "used": gib(lun.get("allocated_size")), "description": lun.get("description", ""),
            "pv": pv["pv"] if pv else "-", "pvc": pv["pvc"] if pv else "-",
            "targets": ts, "sessions": sum(len(t.get("connected_sessions") or []) for t in ts),
        }, pvs


def cmd_list(dsm: DSM, a) -> None:
    out = []
    for r, _ in rows(dsm):
        if a.orphans and r["state"] not in ("ORPHAN", "RELEASED"):
            continue
        hay = " ".join(str(r[k]) for k in ("name", "uuid", "pv", "pvc", "description")).lower()
        if a.find and a.find.lower() not in hay:
            continue
        out.append(r)
    order = {"ORPHAN": 0, "RELEASED": 1}
    out.sort(key=lambda r: (order.get(r["state"], 2), r["name"]))
    if a.json:
        print(json.dumps([{**r, "targets": [t.get("name") for t in r["targets"]]} for r in out], indent=1))
        return
    print(f"{'STATE':9} {'SIZE':>8} {'USED':>8} {'SESS':>4}  {'LUN NAME':50} {'PVC':34} LUN UUID")
    for r in out:
        print(f"{r['state']:9} {r['size']:>8} {r['used']:>8} {r['sessions']:>4}  {r['name'][:50]:50} {r['pvc'][:34]:34} {r['uuid']}")
        if r["description"] and r["description"] != r["pvc"]:
            print(f"{'':33}description: {r['description']}")
    orphans = sum(1 for r in out if r["state"] == "ORPHAN")
    print(f"\n{len(out)} LUNs shown; {orphans} orphaned (no PV), "
          f"{sum(1 for r in out if r['state'] == 'RELEASED')} on Released PVs. Delete: scripts/synology-luns.py delete <uuid>")


def cmd_delete(dsm: DSM, a) -> None:
    match = [(r, pvs) for r, pvs in rows(dsm) if r["uuid"] == a.uuid]
    if not match:
        sys.exit(f"no LUN with uuid {a.uuid}")
    r, pvs = match[0]
    if a.uuid in pvs:
        p = pvs[a.uuid]
        sys.exit(f"refusing: PV {p['pv']} ({p['pvc']}, {p['phase']}) still references this LUN. "
                 f"Delete the PV first (kubectl delete pv {p['pv']}) if its data is no longer needed.")
    if r["sessions"]:
        sys.exit(f"refusing: {r['sessions']} iSCSI session(s) connected to its target(s)")
    own = [t for t in r["targets"] if len(t.get("mapped_luns") or []) == 1]
    shared = [t for t in r["targets"] if t not in own]
    print(f"LUN    {r['name']}  ({r['size']}, used {r['used']})  uuid {r['uuid']}")
    print(f"       description: {r['description'] or '-'}")
    for t in own:
        print(f"target {t.get('name')} (id {t.get('target_id')}): maps only this LUN -> will be deleted")
    for t in shared:
        print(f"target {t.get('name')} (id {t.get('target_id')}): maps other LUNs too -> kept")
    if input(f"\nPermanently delete this LUN and its data? Type the LUN name to confirm: ").strip() != r["name"]:
        sys.exit("not confirmed; nothing deleted")
    for t in own:
        dsm.delete_target(t["target_id"])
        print(f"deleted target {t.get('name')}")
    dsm.delete_lun(r["uuid"])
    print(f"deleted LUN {r['name']}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--client-info", help="local client-info.yml instead of the cluster secret")
    ap.add_argument("--host", help="DSM host, if client-info lists several")
    sub = ap.add_subparsers(dest="cmd")
    ap.add_argument("--orphans", action="store_true", help="only LUNs with no PV, or on Released PVs")
    ap.add_argument("--find", help="substring of LUN name / uuid / PV / PVC / description")
    ap.add_argument("--json", action="store_true")
    d = sub.add_parser("delete", help="delete one orphan LUN (and a target that maps only it)")
    d.add_argument("uuid")
    a = ap.parse_args()
    dsm = DSM(client_info(a.client_info, a.host))
    try:
        cmd_delete(dsm, a) if a.cmd == "delete" else cmd_list(dsm, a)
    finally:
        dsm.logout()


if __name__ == "__main__":
    main()
