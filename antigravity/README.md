# Gemini-Niang Antigravity integration

Local stdio MCP tool `get_antigravity_usage` runs only `agy -p "/usage" --output-format json`.
The Stop hook publishes a tiny local completion event only when `terminationReason` is `model_stop` and `fullyIdle` is true. It never returns `decision: continue`, reads transcript files, or stores user prompts.

Prerequisites: Node.js 20+, Antigravity CLI 1.1.11+ logged in to the same account whose quota you want to display, and the separate Windows desktop companion in the parent repository.

```text
agy plugin validate --strict ./antigravity
agy plugin install ./antigravity
```

For automatic Windows configuration, use the repository's `安装Gemini娘.cmd`. This explicitly installs the plugin and may download the official CLI with SHA512 verification. It does not alter Codex, add autostart, or change PATH. Existing conversations may require a reload/new conversation to pick up hooks.

Desktop and hook share `%LOCALAPPDATA%/GeminiNiang/state` by default. For a custom directory set `GEMINI_NIANG_STATE_DIR` consistently for Antigravity/hook and the desktop process. `PLUGIN_DATA` is intentionally not used as the shared desktop state.

Disable/remove the integration using `agy plugin disable gemini-niang` / `agy plugin uninstall gemini-niang`. Exit the desktop companion from its context menu. State and preferences are retained; no background scheduled task exists.

Notifications are per-local-machine. Remote/cloud execution hooks do not reach a local desktop file spool. Backend unavailable or malformed responses are shown as unavailable, never as a fake remaining percentage.
