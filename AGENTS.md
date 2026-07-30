# AGENTS.md

## Cursor Cloud specific instructions

### What runs where
This repo is primarily an **iOS/Swift game** (`FactoryForge.xcodeproj`, `FactoryForge/`, `FactoryForgeTests/`) that **cannot be built or tested on Linux** — it needs macOS + Xcode + an iOS simulator/device. The Cursor Cloud VM is Linux, so the game and its `xcodebuild` tests are out of scope here.

The runnable-on-Linux pieces are three Node.js/TypeScript projects:

| Project | Path | Runs fully on Linux? | Lint | Build | Run (dev) |
| --- | --- | --- | --- | --- | --- |
| Landing page (React 19 + Vite 8) | `landing/` | Yes | `npm run lint` (oxlint) | `npm run build` | `npm run dev` → http://localhost:5173 |
| Game-control MCP server (Node/TS) | `MCP/` | Starts & serves HTTP on 8080, but full function needs the iOS game | — | `npm run build` (tsc) | `npm start` / `npm run dev` |
| Xcode/LLDB debug MCP server (Node/TS) | `DebugMCP/` | Builds & starts, but only does real work with macOS/Xcode/LLDB | — | `npm run build` (tsc) | `npm start` / `npm run dev` |

### Non-obvious caveats
- **`node_modules/` is committed to git for `MCP/` and `DebugMCP/`, and it contains macOS-only binaries (`@esbuild/darwin-arm64`).** On Linux you must reinstall (`rm -rf node_modules && npm install`) to get the correct native binaries. The startup update script already does a fresh reinstall for these two. Do NOT commit the reinstalled `node_modules` — the platform-specific changes would pollute the repo.
- The **`MCP/` server** exposes an HTTP API on port **8080** (WebSocket on **8081**), but every game command is forwarded to the iOS app on port **8083** (`GameController` → `http://<host>:8083/command`). Without the running game, `game-state` returns `null` and build/move/etc. commands return `{"success":false,"error":"Cannot connect to FactoryForge iOS app ..."}`. That structured error is expected on Linux and confirms the server is up.
- The **landing page** is the only piece that is fully exercisable end-to-end on Linux. Feature blocks under the "Pillars" section have clickable asset-selector buttons that swap the displayed hero image (client-side React state).
- The MCP server's core protocol transport is stdio (`StdioServerTransport`); the HTTP/WS servers start as a side effect of the process. `npm start` runs the built `dist/index.js`, so run `npm run build` first (or use `npm run dev` via `tsx`).
