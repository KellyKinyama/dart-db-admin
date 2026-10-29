# Running the two systems

`dart-db-admin` (this Flutter desktop app) is a GUI for the
[`dart-db-server`](https://github.com/KellyKinyama/dart-db-server) engine. You
run **two processes**: the engine, and the admin app that connects to it.

```
┌─────────────────────────┐     HTTP REST + WebSocket (admin API)
│  dart-db-admin (Flutter) │ ──────────────────────────────────────┐
│  desktop app             │     Oracle TNS/TTC wire (optional)     │
└─────────────────────────┘ ──────────────────────────────┐        │
                                                           ▼        ▼
                                              ┌──────────────────────────────┐
                                              │  dart-db-server process       │
                                              │  :8088 admin API  :1521 oracle │
                                              │  :4556 native JSON  → Database │
                                              └──────────────────────────────┘
```

## Prerequisites

- **Dart SDK** / **Flutter** (desktop enabled). Verify: `flutter doctor`.
- **Windows builds** need the Visual Studio **“Desktop development with C++”**
  workload (MSVC + Windows SDK + CMake).
- The two repos checked out as **siblings** (the app has a path dependency on the
  Oracle driver):
  ```
  ai_projects/
    dart-db-server/     # the engine
    dart-db-admin/      # this app
    dart-oracledb/      # pure-Dart Oracle driver (oracledb), used for Oracle-wire
  ```

## 1. Start the engine

From the engine repo (`dart-db-server`):

```powershell
# Admin API only (in-memory), on 127.0.0.1:8088
dart run bin/dart_db_server.dart --memory --port 4556 --admin-port 8088
```

To also expose the **Oracle wire** protocol (so the app can connect as a real
Oracle client), add the Oracle flags:

```powershell
dart run bin/dart_db_server.dart --memory --port 4556 `
  --admin-port 8088 `
  --oracle-port 1521 --oracle-user admin/admin --oracle-pbkdf2-user admin/admin
```

Flags:

| Flag | Purpose |
|------|---------|
| `--admin-port <n>` | HTTP + WebSocket management API (0 = off) |
| `--admin-token <t>` | require `Authorization: Bearer <t>` on the admin API |
| `--oracle-port <n>` | Oracle TNS/TTC wire listener (e.g. 1521) |
| `--oracle-user u/p` | add an Oracle user (11g verifier) |
| `--oracle-pbkdf2-user u/p` | add an Oracle user (12c PBKDF2 verifier) |
| `--port <n>` | native JSON line protocol (default 4556) |
| `--memory` | in-memory only (no file persistence) |

The engine prints:

```
[db] listening on 127.0.0.1:4556
[oracle] listening on 127.0.0.1:1521 (oracle wire)
admin API on http://127.0.0.1:8088/api
```

> **Op-log**: the Status screen's op-log viewer needs a **file-backed** database
> (omit `--memory` and pass `--file <path>`); `enable` is a no-op in-memory.
> Only wire-protocol writes are logged (ad-hoc `/api/query` writes are not).

## 2. Run the admin app

From this repo (`dart-db-admin`):

```powershell
flutter run -d windows        # or -d macos / -d linux
```

## 3. Connect

Open the **Connect** tab → **New connection**, then pick a transport:

**Admin API (HTTP)** — unlocks every screen (SQL, Schema, Vector, API Probe,
Events, Status):

| Field | Value |
|-------|-------|
| Host | `127.0.0.1` |
| Admin API port | `8088` |
| Bearer token | only if you started with `--admin-token` |

**Oracle wire** — connects as a real Oracle client; drives the **SQL console**
(admin-only screens show a notice):

| Field | Value |
|-------|-------|
| Host | `127.0.0.1` |
| Oracle port | `1521` |
| Service name | `DARTDB` |
| User / Password | `admin` / `admin` |

> The Oracle password is kept in memory only — it is **not** written to disk.

You can open **multiple connections** at once (tabs at the top) and switch
between them; each screen re-queries the active connection.

## Ports at a glance

| Port | Protocol | Used by |
|------|----------|---------|
| 8088 | HTTP REST + WS (`/api/...`) | admin app (all screens) |
| 1521 | Oracle TNS/TTC | admin app (Oracle-wire SQL), any Oracle client |
| 4556 | native JSON line | `dart_db_client`, tooling |

## Smoke-test tooling

Quick checks against a running engine:

```powershell
# HTTP admin API (health/info/query/tables/vector/...)
powershell -File tool/probe.ps1

# WebSocket event stream (hello + request + heartbeat)
dart run tool/ws_probe.dart

# Vector search modes (k-NN / filtered / range / hybrid)
powershell -File tool/vector_probe.ps1

# Oracle-wire path via the app's OracleClient
dart run tool/oracle_client_probe.dart
```

## Automated tests

```powershell
flutter test                      # app unit tests
# engine side:
#   cd ../dart-db-server ; dart test test/admin_api_test.dart
```

## Keyboard shortcuts

- `Ctrl+1 … 8` — switch screens (Connect, SQL, Schema, Vector, API Probe,
  Events, Status, Users)
- `Ctrl+Enter` — run SQL (SQL console)
- `Ctrl+D` — cycle theme (system → light → dark)

## Screens

| Screen | Needs | What it does |
|--------|-------|--------------|
| **Connect** | — | Manage connections (Admin API or Oracle wire); multiple open at once |
| **SQL** | either | Run SQL/PLSQL; history, CSV/JSON export, max-rows cap, destructive-SQL confirm |
| **Schema** | Admin API | Browse tables/views + column detail |
| **Vector** | Admin API | List vector indexes; k-NN / filtered / range / hybrid search |
| **API Probe** | Admin API | Discover and fire raw admin-API requests |
| **Events** | Admin API | Live WebSocket event stream (heartbeat + requests) |
| **Status** | Admin API | Metric dashboard, auto-refresh, LSN sparkline, op-log viewer |
| **Users** | Admin API + `--oracle-port` | List and add Oracle users |

> Oracle-wire connections drive the **SQL** screen; the admin-only screens show
> a notice (they need an Admin API connection for engine metadata).

