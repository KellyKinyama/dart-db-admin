# dart-db-admin — Project Plan

A cross-platform **Flutter desktop** administration tool for the
[`dart-db-server`](../dart-db-server) engine (SQL + vector store, multi-protocol).

---

## 1. Goals

- A desktop admin GUI (Windows / macOS / Linux) to operate a running dart-db
  engine: run SQL, browse schema, manage vector collections, watch server
  status, and manage users.
- Talk to the engine over a **stable HTTP REST + WebSocket management API** (not
  the raw wire protocols), so the UI is decoupled from protocol internals and a
  future web build is possible.
- Zero coupling: the Flutter app depends only on HTTP/JSON — never on the engine
  package.

## 2. Architecture

```
┌──────────────────────────┐        HTTP REST (+ WebSocket events)
│  dart-db-admin (Flutter) │  ───────────────────────────────────────┐
│  desktop app             │                                          │
│  - Connection manager    │                                          ▼
│  - SQL console + grid    │                         ┌─────────────────────────────┐
│  - Schema browser        │                         │  dart-db-server process      │
│  - Vector manager        │                         │  ┌────────────────────────┐  │
│  - Status / monitoring   │                         │  │ AdminApiServer (NEW)   │  │
│  - User management       │                         │  │  HTTP + WS, :8088      │  │
└──────────────────────────┘                         │  └──────────┬─────────────┘  │
                                                      │             │ direct calls   │
                                                      │       ┌─────▼──────┐          │
                                                      │       │  Database  │          │
                                                      │       └────────────┘          │
                                                      │   (also: native :4555,        │
                                                      │    Oracle/MySQL wire ports)   │
                                                      └─────────────────────────────┘
```

**Why an embedded management API (not the native `DbClient`):** the admin tool
needs engine state the SQL wire doesn't expose (HA status, vector-index specs,
server info). The `AdminApiServer` runs **in the engine process** with a direct
`Database` reference, so it has full access. It is opt-in via `--admin-port`.

## 3. Management API (engine side — `dart-db-server/lib/server/admin_api.dart`)

Dependency-free (`dart:io` `HttpServer`). JSON over HTTP; optional bearer token.

| Method | Path | Purpose |
|---|---|---|
| GET  | `/api/health` | liveness probe |
| GET  | `/api/info` | engine version, db path, in-memory?, HA role |
| POST | `/api/query` | `{sql, maxRows?}` → one or more `QueryResult`s |
| GET  | `/api/tables` | list tables (name, row count, column count) |
| GET  | `/api/tables/{name}` | columns, indexes, constraints |
| GET  | `/api/views` | list views |
| GET  | `/api/vector/indexes` | vector index specs |
| GET  | `/api/status` | HA status (role, epoch, lsn, fenced) |
| GET  | `/api/sessions` | active sessions / connection stats (best-effort) |
| WS   | `/api/events` | server-pushed status/log events (phase 2) |

`QueryResult.toJson()` already exists → `{columns, columnTypes, rows, affected, message}`.
Metadata endpoints are driven by `Database` accessors (`haStatus`,
`vectorIndexes`) and SQL introspection where needed.

Auth: optional `--admin-token <t>`; when set, the API requires
`Authorization: Bearer <t>`. Bind defaults to `127.0.0.1`.

## 4. Flutter app structure (`dart-db-admin/lib/`)

```
lib/
  main.dart                 app entry, theme, root shell
  models/                   plain Dart data classes (JSON)
    connection.dart           ServerConnection (host, port, token, name)
    query_result.dart         QueryResult (columns, columnTypes, rows, affected)
    table_info.dart           TableInfo, ColumnInfo, IndexInfo
    vector_index.dart         VectorIndexInfo
    server_status.dart        ServerStatus (HA, info)
  services/
    admin_api_client.dart     HTTP client wrapping the management API
    connection_store.dart     persist saved connections (shared_preferences)
  state/
    app_state.dart            ChangeNotifier: active connection, health
    query_state.dart          run SQL, history, results
  screens/
    home_shell.dart           nav rail + routed body
    connect_screen.dart       connection manager (add/edit/connect)
    sql_console_screen.dart   editor + results grid
    schema_screen.dart        table/view browser
    vector_screen.dart        vector index/collection manager
    status_screen.dart        server status / monitoring
    users_screen.dart         user management
  widgets/
    results_grid.dart         virtualized data grid
    sql_editor.dart           SQL text field (monospace, run shortcut)
    connection_badge.dart     active-connection indicator
```

**State:** `provider` + `ChangeNotifier` (simple, enough for this scope).
**HTTP:** `http`. **Live events:** `web_socket_channel` (phase 2).
**Grid:** `data_table_2` for virtualized results.
**Persistence:** `shared_preferences` for saved connections (tokens stored
redacted / opt-in only).

## 5. Milestones

- **M0 — Foundation (this iteration)**
  - Flutter project scaffolded (win/macos/linux), deps added, structure in place.
  - Engine: `AdminApiServer` + `--admin-port` wiring; `/health`, `/info`, `/query`.
  - App: connection manager + SQL console vertical slice (connect → run SQL →
    results grid). End-to-end against a locally running engine.
- **M1 — Schema browser**: `/tables`, `/tables/{name}`, `/views`; tree + detail.
- **M2 — Server status**: `/status`, `/info` dashboard; auto-refresh.
- **M3 — Vector manager**: `/vector/indexes`; create/drop index, similarity
  search panel.
- **M4 — User management**: list/create/alter users and grants (via SQL +
  dedicated endpoints).
- **M5 — Live monitoring**: WebSocket `/api/events`, session list, op-log/LSN
  charts, replication view.
- **M6 — Polish**: query history, result export (CSV/JSON), themes, keyboard
  shortcuts, multi-connection tabs, packaging/installers.

## 6. Security & safety

- Admin API binds to `127.0.0.1` by default; optional bearer token for remote.
- Destructive SQL (DROP/DELETE/TRUNCATE) gated behind a confirm dialog.
- Tokens never logged; saved-connection token storage is opt-in.

## 7. Testing

- Engine: unit tests for `AdminApiServer` handlers (in-memory `Database`).
- App: widget tests for the results grid + model JSON round-trips; a fake
  `AdminApiClient` for screen tests.

## 8. Out of scope (for now)

- Web build (needs CORS + token UX hardening).
- Schema editing/migrations UI (read + ad-hoc SQL first).
- Multi-user RBAC for the admin tool itself.
