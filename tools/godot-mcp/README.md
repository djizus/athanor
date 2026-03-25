# Godot MCP Server

Remote MCP server that exposes Godot engine operations as tools. Run on a machine with GPU + Godot installed, connect via SSH tunnel.

## Setup

```bash
cd tools/godot-mcp
npm install
```

## Run (WSL on JC-LEGION)

```bash
cd ~/athanor/tools/godot-mcp

GODOT_PATH="C:\Users\mehrj\Desktop\Godot_v4.6.1-stable_win64.exe" \
PROJECT_PATH="\\\\wsl.localhost\\Ubuntu\\home\\djizus\\athanor\\client" \
node server.js
```

## SSH Tunnel

From WSL to the remote opencode server:

```bash
ssh -R 8080:localhost:8080 -p 16422 -i /mnt/c/Users/mehrj/.ssh/djizus_key djizus@135.181.18.52
```

This forwards remote port 8080 → local port 8080 where the MCP server runs.

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
