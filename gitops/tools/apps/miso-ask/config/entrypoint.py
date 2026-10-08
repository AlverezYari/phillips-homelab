"""miso-ask entrypoint: build Open WebUI's JSON settings from plain files and secrets, then exec
the image's start.sh. Settings that are plain strings live in settings.env (envFrom); this only
assembles the ones Open WebUI wants as JSON:

- OPENAI_API_*: one connection, Anthropic's OpenAI-compatible endpoint, fixed model list
  (so nothing calls /models).
- TOOL_SERVER_CONNECTIONS: the two iso-lab MCP servers in-cluster, bearer token from the secret,
  readable by every signed-in user.
- DEFAULT_MODEL_METADATA: both MCP servers on by default in every chat, uploads/web/images off.
- DEFAULT_MODEL_PARAMS: native tool calling, max_tokens.
- The system prompt (system-prompt.md) goes on stored model entries instead: Open WebUI drops a
  global default 'system'. sync_models.py upserts them once the server is up (a child process).
- DEFAULT_PROMPT_SUGGESTIONS: prompt-suggestions.json.

ENABLE_PERSISTENT_CONFIG=false (settings.env) makes this env the source of truth: admin UI edits
do not persist, so the deployed config is always what is in git.
"""

import json
import os
import sys
from pathlib import Path

CONFIG = Path(os.environ.get("MISO_ASK_CONFIG", "/etc/miso-ask"))
MODELS = ["claude-sonnet-5-5", "claude-opus-5-5"]
MCP = {
    # server id (tool-name prefix the system prompt uses) -> in-cluster URL
    "iso": ("ISO SQL (read-only)", "http://mcp-clickhouse.iso-lab.svc.cluster.local/mcp"),
    "iso_analysis": ("ISO analysis", "http://iso-analysis.iso-lab.svc.cluster.local/mcp"),
}
EVERYONE = [{"principal_type": "user", "principal_id": "*", "permission": "read"}]


def build(env: dict[str, str], config: Path = CONFIG) -> dict[str, str]:
    for k in ("ANTHROPIC_API_KEY", "ISO_MCP_TOKEN"):
        if len(env.get(k, "")) < 16:
            raise SystemExit(f"{k} must be set (secret miso-ask)")
    tools = [
        {
            "type": "mcp",
            "url": env.get(f"MCP_URL_{sid.upper()}", url),  # override: local tests only
            "path": "",
            "auth_type": "bearer",
            "key": env["ISO_MCP_TOKEN"],
            "config": {"enable": True, "access_grants": EVERYONE},
            "info": {"id": sid, "name": name, "description": name},
        }
        for sid, (name, url) in MCP.items()
    ]
    return {
        "OPENAI_API_BASE_URLS": "https://api.anthropic.com/v1",
        "OPENAI_API_KEYS": env["ANTHROPIC_API_KEY"],
        "OPENAI_API_CONFIGS": json.dumps(
            {"0": {"enable": True, "connection_type": "external", "model_ids": MODELS}}
        ),
        "DEFAULT_MODELS": MODELS[0],
        "TASK_MODEL_EXTERNAL": MODELS[0],
        "TOOL_SERVER_CONNECTIONS": json.dumps(tools),
        "DEFAULT_MODEL_METADATA": json.dumps(
            {
                "toolIds": [f"server:mcp:{sid}" for sid in MCP],
                "capabilities": {
                    "file_upload": False,
                    "web_search": False,
                    "image_generation": False,
                    "code_interpreter": False,
                    # Open WebUI's own tools (knowledge bases, chat search, tasks, time): off, so
                    # the model sees only the two iso-lab MCP servers.
                    "builtin_tools": False,
                    "vision": False,
                    "citations": True,
                    "usage": True,
                },
            }
        ),
        "DEFAULT_MODEL_PARAMS": json.dumps(
            {
                "function_calling": "native",
                "max_tokens": 8192,
            }
        ),
        "DEFAULT_PROMPT_SUGGESTIONS": (config / "prompt-suggestions.json").read_text(),
    }


if __name__ == "__main__":
    os.environ.update(build(dict(os.environ)))
    for k in ("ANTHROPIC_API_KEY", "ISO_MCP_TOKEN"):
        os.environ.pop(k)
    start = sys.argv[1:] or ["bash", "/app/backend/start.sh"]
    if os.fork() == 0:  # child: write the model entries once the server is healthy, then exit
        os.chdir("/app/backend")
        os.execvp("python3", ["python3", str(CONFIG / "sync_models.py")])
    os.execvp(start[0], start)
