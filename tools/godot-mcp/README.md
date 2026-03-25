# Godot MCP Server

Remote MCP server that exposes Godot engine operations as tools. Run on a machine with GPU + Godot installed, connect via SSH tunnel.

## Setup

```bash
cd ~/athanor/tools/godot-mcp
npm install
```

## Run (WSL on JC-LEGION)

```bash
cd ~/athanor/tools/godot-mcp

GODOT_PATH="/mnt/c/Users/mehrj/Desktop/Godot_v4.6.1-stable_win64.exe" \
PROJECT_PATH="/home/djizus/athanor/client" \
node server.js
```

If Godot needs Windows-style project path:

```bash
GODOT_PATH="/mnt/c/Users/mehrj/Desktop/Godot_v4.6.1-stable_win64.exe" \
PROJECT_PATH="$(wslpath -w /home/djizus/athanor/client)" \
node server.js
```

## SSH Tunnel

From a **separate WSL terminal** to the remote opencode server:

```bash
chmod 600 ~/.ssh/djizus_key
ssh -R 8080:localhost:8080 -p 16422 -i ~/.ssh/djizus_key djizus@135.181.18.52
```

This forwards remote port 8080 → local port 8080 where the MCP server runs.
Keep this terminal open — closing it kills the tunnel.

Note: `AllowTcpForwarding yes` must be set in `/etc/ssh/sshd_config.d/hardening.conf` on the server.

## OpenCode Config

On the server (`opencode.jcmehr.com`), add to `~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "mcp": {
    "godot": {
      "type": "remote",
      "url": "http://localhost:8080/mcp",
      "enabled": true
    }
  }
}
```

## Quick Start (all 3 terminals)

```bash
# Terminal 1: MCP server
cd ~/athanor/tools/godot-mcp
GODOT_PATH="/mnt/c/Users/mehrj/Desktop/Godot_v4.6.1-stable_win64.exe" \
PROJECT_PATH="/home/djizus/athanor/client" \
node server.js

# Terminal 2: SSH tunnel
ssh -R 8080:localhost:8080 -p 16422 -i ~/.ssh/djizus_key djizus@135.181.18.52

# Terminal 3: Verify
curl http://localhost:8080/health
```

## Tools

| Tool | Description |
|------|-------------|
| `godot_parse_check` | Validate all scripts (headless) |
| `godot_run_tests` | Run all test_*.gd suites |
| `godot_capture_scene` | Capture frames via --write-movie |
| `godot_read_frame` | Read a PNG frame as base64 |
| `godot_launch` | Launch Godot with GPU for interactive testing |
| `godot_stop` | Kill running Godot process |
| `godot_screenshot` | Capture current screen |
| `godot_click` | Mouse click at (x, y) |
| `godot_press_key` | Send keyboard input |
| `godot_logs` | Read process stdout/stderr |
| `godot_wait` | Pause between operations |

## Environment Variables

| Var | Default | Description |
|-----|---------|-------------|
| `GODOT_PATH` | `godot` | Path to Godot binary |
| `PROJECT_PATH` | `./client` | Path to Godot project |
| `PORT` | `8080` | Server port |
| `SCREENSHOT_DIR` | `PROJECT_PATH/screenshots/mcp` | Screenshot output |
