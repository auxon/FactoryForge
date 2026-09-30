"""Headless Blender MCP bridge.

Blender 5.1 background mode has no event loop, so bpy.app.timers never
fire and the addon's auto-start path is skipped. This script imports the
addon module directly, starts its socket server (port 9876), and pumps
the command queue on the main thread forever. All bpy access stays on
the main thread, exactly as the GUI timer path would do.
"""
import sys
import time

sys.path.insert(0, "/home/rah/.config/blender/5.1/scripts/addons")

import blender_mcp  # noqa: E402
import socket as _socket
import threading as _threading


def _manual_start(srv):
    """Replicates BlenderMCPServer.start() minus the background-mode guard.
    The watchdog drain loop below replaces bpy.app.timers."""
    srv.running = True
    srv.socket = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
    srv.socket.setsockopt(_socket.SOL_SOCKET, _socket.SO_REUSEADDR, 1)
    srv.socket.bind((srv.host, srv.port))
    srv.socket.listen(5)
    srv.server_thread = _threading.Thread(target=srv._server_loop)
    srv.server_thread.daemon = True
    srv.server_thread.start()
    print(f"BlenderMCP server started on {srv.host}:{srv.port}", flush=True)


srv = blender_mcp.BlenderMCPServer(host="localhost", port=9876)
_manual_start(srv)
print("HEADLESS-BRIDGE-UP", flush=True)
while True:
    try:
        srv._drain_command_queue()
    except Exception as e:  # never let the pump die
        print("drain error:", e, flush=True)
    time.sleep(0.02)
