"""llm-gateway: make LiteLLM's virtual keys match keys.json (budgets, limits, allowed models).

Runs as a Job after each Argo sync. Each key's value comes from the env (1Password); everything else from
keys.json, so git is the source of truth. Creates a missing key, updates an existing one: safe to rerun.
Stdlib only (runs in the LiteLLM image). Env: LITELLM_URL, LITELLM_MASTER_KEY, KEYS_FILE, KEY_* values.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get("LITELLM_URL", "http://litellm:4000").rstrip("/")
MASTER = os.environ["LITELLM_MASTER_KEY"]


def call(method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
    req = urllib.request.Request(
        URL + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {MASTER}", "content-type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def wait_ready(seconds: int = 300) -> None:
    deadline = time.time() + seconds
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(URL + "/health/readiness", timeout=5) as r:
                if r.status == 200:
                    return
        except OSError:
            pass
        time.sleep(5)
    sys.exit("llm-gateway sync_keys: LiteLLM never became ready")


def spec_body(k: dict, value: str) -> dict:
    return {
        "key": value,
        "key_alias": k["alias"],
        "max_budget": k["budget_usd"],
        "budget_duration": k["budget_duration"],
        "rpm_limit": k["rpm_limit"],
        "models": k["models"],
        "metadata": {"consumer": k["consumer"], "managed_by": "gitops keys.json"},
        "object_permission": {"mcp_servers": k.get("mcp_servers", [])},
    }


def main() -> None:
    with open(os.environ.get("KEYS_FILE", "/etc/litellm/keys.json")) as f:
        keys = json.load(f)["keys"]
    wait_ready()
    failed = 0
    for k in keys:
        value = os.environ.get(k["env"], "")
        if not value:  # its 1Password field doesn't exist yet: the next sync picks it up
            print(f"{k['alias']}: skipped, {k['env']} has no value yet", flush=True)
            continue
        if not value.startswith("sk-"):
            print(f"{k['alias']}: {k['env']} doesn't start with sk-", flush=True)
            failed += 1
            continue
        status, _ = call("GET", "/key/info?key=" + urllib.request.quote(value, safe=""))
        path = "/key/update" if status == 200 else "/key/generate"
        status, out = call("POST", path, spec_body(k, value))
        ok = status == 200
        failed += not ok
        print(f"{k['alias']}: {path} -> {status}" + ("" if ok else f" {json.dumps(out)[:300]}"), flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
