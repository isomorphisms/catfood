# Gopeed REST API

Cat Food carries this page as the quick reference for controlling Gopeed from Termux or another local client.

## Availability on Android

The native Gopeed app does **not** need HTTP to operate internally; native builds invoke the Go backend directly. The same backend also exposes its REST server. In the current `isomorphisms/gopeed` mirror, native startup enables that REST server by default when no API configuration has been stored yet. An existing stored API configuration still wins, so an explicit `enable: false` remains disabled.

The initialized REST defaults are:

- enabled: `true` for a fresh/unset native API configuration
- network: `tcp`
- address: `127.0.0.1:9999`
- token: empty unless configured

The default listener is therefore loopback-only: Termux on the same Android device can reach it, but it is not exposed to the LAN. A particular installed Android build still needs runtime verification; check it with `GET /api/v1/info` or `gopeed info` rather than treating source configuration as a physical-device receipt.

```sh
GOPEED=http://127.0.0.1:9999
curl -sS "$GOPEED/api/v1/info"
```

If an API token is configured, add either:

```sh
-H "X-Api-Token: $GOPEED_API_TOKEN"
```

or `Authorization: Bearer $GOPEED_API_TOKEN` to requests. With no API token and no web authentication configured, the REST API has no token check.

## Cat Food command

Cat Food installs a small `gopeed` command that submits a URL to the local REST service. `gdl` and `go_down_load` are aliases of the same command.

```sh
gopeed https://example.com/file
gdl https://example.com/file
go_down_load https://example.com/file
```

With no URL argument the command reads one URL from standard input, so a resolved Anna's Archive member URL can go straight to Gopeed:

```sh
aa resolve MD5 | gdl
```

`gopeed info` checks `/api/v1/info`. Set `GOPEED_URL` to use a nondefault REST base URL and `GOPEED_API_TOKEN` when the server requires a token. The command uses `curl` only for the small REST control request; Gopeed performs the actual file transfer.

Cat Food's conditional `aa` wrapper also carries a future handoff: after a successful `aa search`, it prints

```text
next: aa resolve <MD5> | gdl    # gdl = go_down_load = gopeed
```

The current `az` `AA` branch intentionally does **not** implement `aa search`; it only has the stable member fast-download resolver. The hook therefore stays dormant rather than inventing an HTML scraper or claiming search support that does not exist.

## Endpoints

These are the routes registered by the current `isomorphisms/gopeed` mirror.

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/v1/info` | backend version, Go runtime, OS and architecture |
| `POST` | `/api/v1/resolve` | resolve a download request before creating a task |
| `POST` | `/api/v1/tasks` | create one task; accepts a resolved `rid` or a direct request |
| `POST` | `/api/v1/tasks/batch` | create multiple direct tasks |
| `GET` | `/api/v1/tasks` | list/filter tasks |
| `GET` | `/api/v1/tasks/{id}` | get one task |
| `PATCH` | `/api/v1/tasks/{id}` | change a task request/options |
| `DELETE` | `/api/v1/tasks/{id}` | delete one task; `?force=true` also removes data where supported |
| `DELETE` | `/api/v1/tasks` | delete tasks selected by query filters |
| `PUT` | `/api/v1/tasks/{id}/pause` | pause one task |
| `PUT` | `/api/v1/tasks/pause` | pause tasks selected by query filters |
| `PUT` | `/api/v1/tasks/{id}/continue` | continue one task |
| `PUT` | `/api/v1/tasks/continue` | continue tasks selected by query filters |
| `GET` | `/api/v1/tasks/{id}/status` | current runtime progress/status |
| `GET` | `/api/v1/tasks/{id}/stats` | task transfer statistics |
| `GET` | `/api/v1/config` | read downloader configuration |
| `PUT` | `/api/v1/config` | replace/update downloader configuration |
| `POST` | `/api/v1/extensions` | install an extension |
| `GET` | `/api/v1/extensions` | list extensions |
| `GET` | `/api/v1/extensions/{identity}` | get one extension |
| `PUT` | `/api/v1/extensions/{identity}/settings` | update extension settings |
| `PUT` | `/api/v1/extensions/{identity}/switch` | enable/disable an extension |
| `DELETE` | `/api/v1/extensions/{identity}` | uninstall an extension |
| `GET` | `/api/v1/extensions/{identity}/update` | check for an extension update |
| `POST` | `/api/v1/extensions/{identity}/update` | perform an extension update |
| `POST` | `/api/v1/webhook/test` | test a webhook URL |

Task-list/action filters use repeated query parameters: `id`, `status`, and `notStatus`.

The HTTP server also has auxiliary routes:

| Method | Path | Purpose |
| --- | --- | --- |
| any | `/api/web/proxy` | proxy a request to the URI in `X-Target-Uri`; Gopeed strips cookies and its own API headers before forwarding |
| `POST` | `/api/web/login` | web-UI login; only present when the web server and web authentication are enabled |
| any | `/mcp` | optional MCP endpoint when MCP is enabled |

## Termux examples

List tasks:

```sh
GOPEED=http://127.0.0.1:9999
curl -sS "$GOPEED/api/v1/tasks"
```

Create a direct HTTP task:

```sh
curl -sS \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"req":{"url":"https://example.com/file"}}' \
  "$GOPEED/api/v1/tasks"
```

Choose a name and download directory:

```sh
curl -sS \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"req":{"url":"https://example.com/file"},"opts":{"name":"file.bin","path":"/storage/emulated/0/Download"}}' \
  "$GOPEED/api/v1/tasks"
```

Inspect, pause, continue, then delete a task:

```sh
id=TASK_ID
curl -sS "$GOPEED/api/v1/tasks/$id"
curl -sS -X PUT "$GOPEED/api/v1/tasks/$id/pause"
curl -sS -X PUT "$GOPEED/api/v1/tasks/$id/continue"
curl -sS -X DELETE "$GOPEED/api/v1/tasks/$id"
```

Resolve first when a source or extension needs discovery before task creation:

```sh
curl -sS \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"req":{"url":"https://example.com/file"}}' \
  "$GOPEED/api/v1/resolve"
```

The response envelope is normally JSON of the form `{ "code": ..., "msg": ..., "data": ... }`; application success is `code == 0`.

## Cat Food boundary

Gopeed is an optional runtime/download service, not a Cat Food bootstrap prerequisite. Plain `curl` remains the smaller choice for a known direct URL. Gopeed is useful when Cat Food wants persistent queued transfers, task state, resume/retry, or extension-backed resolution.

Source of truth in the mirror:

- `pkg/api/service.go` — registered REST routes
- `pkg/base/model.go` — API-server and request/config models
- `pkg/rest/server.go` — HTTP listener, authentication, proxy and MCP wiring
- `pkg/rest/model/task.go` — resolve/create task request envelopes
