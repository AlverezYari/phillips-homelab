"""miso-ask: write the Claude model entries (system prompt, tools, name) into Open WebUI's database.

Open WebUI only sends a system prompt that lives on a *stored* model entry: the global
DEFAULT_MODEL_PARAMS 'system' is merged into the request and then dropped (0.11.4,
routers/openai.py applies `params.system` only when Models.get_model_by_id finds a row). So
entrypoint.py runs this once per boot, after the server is up, and upserts one override row per
base model (same id, base_model_id NULL) from config/: what runs is still what is in git. Edits made
in Workspace > Models are overwritten at the next restart.

Uses Open WebUI's own data layer (open_webui.models.models), so the row matches the schema of the
pinned image. Run inside the Open WebUI image with the server's env.
"""

import asyncio
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

CONFIG = Path(os.environ.get("MISO_ASK_CONFIG", "/etc/miso-ask"))
NAMES = {"claude-sonnet-5-5": "MISO analyst · Sonnet 5.5", "claude-opus-5-5": "MISO analyst · Opus 5.5"}
DESCRIPTION = "Public MISO market data: read-only SQL and fixed statistical tools. Answers link to the query behind them."


def wait_for_server(port: str, timeout: int = 600) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=5).status == 200:
                return
        except OSError:  # not listening yet (URLError and connection errors are OSErrors)
            pass
        time.sleep(3)
    raise SystemExit("miso-ask sync_models: server never became healthy")


def rows(env: dict[str, str], config: Path = CONFIG) -> list[dict]:
    meta = json.loads(env["DEFAULT_MODEL_METADATA"])
    params = json.loads(env["DEFAULT_MODEL_PARAMS"])
    params["system"] = (config / "system-prompt.md").read_text().strip()
    return [
        {
            "id": model_id,
            "base_model_id": None,
            "name": name,
            "meta": {**meta, "description": DESCRIPTION},
            "params": params,
            "is_active": True,
        }
        for model_id, name in NAMES.items()
    ]


async def upsert(entries: list[dict]) -> None:
    from open_webui.models.models import ModelForm, Models
    from open_webui.models.users import Users

    admin = await Users.get_super_admin_user() if hasattr(Users, "get_super_admin_user") else None
    owner = admin.id if admin else "miso-ask"
    for e in entries:
        form = ModelForm(**e)
        if await Models.get_model_by_id(e["id"]):
            ok = await Models.update_model_by_id(e["id"], form)
        else:
            ok = await Models.insert_new_model(form, owner)
        print(f"miso-ask sync_models: {e['id']} -> {'ok' if ok else 'FAILED'}", flush=True)
        if not ok:
            raise SystemExit(1)


if __name__ == "__main__":
    wait_for_server(os.environ.get("PORT", "8080"))
    # The server's start.sh loads the session key from this file; the data layer's env checks need it too.
    key_file = Path(os.environ.get("WEBUI_SECRET_KEY_FILE", "/data/.webui_secret_key"))
    if not os.environ.get("WEBUI_SECRET_KEY") and key_file.exists():
        os.environ["WEBUI_SECRET_KEY"] = key_file.read_text().strip()
    sys.path.insert(0, "/app/backend")
    asyncio.run(upsert(rows(dict(os.environ))))
