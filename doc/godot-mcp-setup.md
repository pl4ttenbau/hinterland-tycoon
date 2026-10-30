# Godot MCP bridge setup

This branch installs godot-mcp-bridge **1.2.1**, from
https://github.com/TomasLucasUTN/godot-mcp-bridge (MIT).
The addon is vendored from the matching npm release in `addons/godot_mcp`.
Its editor plugin is enabled and `MCPRuntime` is registered for runtime tools.

Project-scoped Codex configuration is in `.codex/config.toml`. It pins the same
server release and enables runtime, debugging, code intelligence, and editor
activity tools at startup. `GODOT_MCP_PROJECT` restricts connections to this
checkout. The configuration uses this machine's bundled Node runtime (Node 24),
because the system Node 18 is older than a transitive dependency requires.
Update the absolute project, Node, and Godot paths when moving this checkout.

Save your editor work, then restart the Godot project and restart Codex to load
the configuration. The editor should display **MCP Connected** in green.
The project must be trusted for Codex to load project-scoped configuration.

Diagnostics: `npx --yes godot-mcp-bridge@1.2.1 doctor` (Node 20+).
Port 6505 must be available; keep only one bridge server for this project running.
The server needs a running Godot editor for editor tools.

The runtime autoload connects to the bridge when the game starts. This is a
development integration; remove the addon and MCPRuntime autoload before shipping
if you do not want the bridge in exported games.

## Verification

Verified with Godot 4.7.2: the server initialized over MCP, exposed the configured
toolsets, connected to this project's headless editor with matching addon/server
versions, and successfully read `res://scenes/game_session.tscn` at depth 1.
The temporary test server and editor were closed after verification.
This validates the bridge connection and scene inspection, not the full game.
