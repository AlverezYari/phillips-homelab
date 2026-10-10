"""miso-ask entrypoint: build Open WebUI's JSON settings from plain files and secrets, then exec
the image's start.sh. Settings that are plain strings live in settings.env (envFrom); this only
assembles the ones Open WebUI wants as JSON:

- OPENAI_API_*: one connection, the homelab's LLM gateway (LiteLLM, OpenAI-compatible; LLM_BASE_URL,
  LLM_API_KEY: this chat's own gateway key and budget), fixed model list (so nothing calls /models).
  Without LLM_BASE_URL (local runs) it is Anthropic's OpenAI-compatible endpoint with ANTHROPIC_API_KEY.
- TOOL_SERVER_CONNECTIONS: one MCP connection, "lab", to the LLM gateway's /mcp/ with this chat's gateway
  key; the gateway fronts the lab's two MCP servers (tools "iso_*" SQL, "analysis_*") and holds their token.
  Readable by every signed-in user.
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
    # server id (Open WebUI's tool-name prefix: tools are "lab_iso_*" and "lab_analysis_*") -> URL. The LLM gateway
    # serves both lab MCP servers at /mcp/, limited to the ones this key may use (llm-gateway/keys.json).
    "lab": (
        "MISO lab (SQL and analysis, via the LLM gateway)",
        "http://litellm.llm-gateway.svc.cluster.local:4000/mcp/",
    ),
}
EVERYONE = [{"principal_type": "user", "principal_id": "*", "permission": "read"}]


def build(env: dict[str, str], config: Path = CONFIG) -> dict[str, str]:
    key = env.get("LLM_API_KEY") or env.get("ANTHROPIC_API_KEY", "")
    if len(key) < 16:
        raise SystemExit("LLM_API_KEY (or ANTHROPIC_API_KEY) must be set (secret miso-ask)")
    tools = [
        {
            "type": "mcp",
            "url": env.get(f"MCP_URL_{sid.upper()}", url),  # override: local tests only
            "path": "",
            "auth_type": "bearer",
            "key": key,  # this chat's gateway key: the gateway checks which MCP servers it may use
            "config": {"enable": True, "access_grants": EVERYONE},
            "info": {"id": sid, "name": name, "description": name},
        }
        for sid, (name, url) in MCP.items()
    ]
    return {
        "OPENAI_API_BASE_URLS": env.get("LLM_BASE_URL", "https://api.anthropic.com/v1"),
        "OPENAI_API_KEYS": key,
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
                "max_tokens": 16000,
            }
        ),
        "DEFAULT_PROMPT_SUGGESTIONS": (config / "prompt-suggestions.json").read_text(),
    }


if __name__ == "__main__":
    os.environ.update(build(dict(os.environ)))
    for k in ("LLM_API_KEY", "ANTHROPIC_API_KEY", "ISO_MCP_TOKEN"):
        os.environ.pop(k, None)
    start = sys.argv[1:] or ["bash", "/app/backend/start.sh"]
    if os.fork() == 0:  # child: write the model entries once the server is healthy, then exit
        os.chdir("/app/backend")
        os.execvp("python3", ["python3", str(CONFIG / "sync_models.py")])
    os.execvp(start[0], start)
