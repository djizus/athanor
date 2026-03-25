# Godot MCP Server

Remote MCP server that exposes Godot engine operations as tools. Run on a machine with GPU + Godot installed, connect via SSH tunnel.

## Setup

```bash
cd tools/godot-mcp
npm install
```

## Run

```bash
# Windows (Godot in PATH)
set GODOT_PATH=C:\path\to\Godot_v4.5.2-stable_win64.exe
set PROJECT_PATH=C:\path\to\athanor\client
node server.js

# Linux/Mac
GODOT_PATH=/usr/local/bin/godot PROJECT_PATH=./client node server.js
```

## SSH Tunnel

From your local machine to the remote server:

```bash
ssh -R 8080:localhost:8080 djizus@your-server
```

## OpenCode Config

On the server, add to `~/.config/opencode/opencode.jsonc`:

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
