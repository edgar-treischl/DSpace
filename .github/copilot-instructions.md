# Copilot Instructions

## Build, run, and ops
- Prereqs: Docker ≥ 24 and Compose v2; ensure ports 80, 8080, 8000, 9001, 15672 are free on the single VM host.
- Setup flow: copy `.env` and set `DSPACE_DB_PASSWORD` plus admin credentials, then `make build`, `make up`, `make setup` (DB/search init, admin user, frontend assets), open http://localhost:8080.
- Ops commands: `make logs` (all services), `make logs-web-ui` (single service tail), `make shell` (bash in web-ui), `make cli cmd="db info"` (run DSpace CLI), `make status` (container health), `make clean` (stop + drop volumes), `make ingest token=<token>` (loads datasets/iris: creates draft, uploads data.csv/schema.json/README.md, publishes, writes datasets/iris/checksums.txt).
- Tests/lint: none documented; workflow centers on the dockerized make targets.

## Architecture
- Docker Compose stack fronted by Nginx (:80) routing to Spring Boot web-ui (:8080) and web-api (:8000); both reuse the locally built DSpace image along with a worker for background jobs.
- Backing services: Postgres (metadata DB), Solr (search), Redis (cache/session/task results), RabbitMQ (message broker), MinIO (S3-compatible object storage).
- Consoles: RabbitMQ at http://localhost:15672 (guest/guest); MinIO at http://localhost:9001 (MINIO_ROOT_USER / MINIO_ROOT_PASSWORD).

## Conventions
- Prefer the provided `make` targets for lifecycle actions instead of manual docker-compose commands.
- Environment config lives in `.env`; set DB password and admin credentials before building/starting.
- Datasets live under `datasets/<name>/` with `data.csv`, `schema.json`, `metadata.json`, `README.md`; ingest command generates `checksums.txt`.
- Dataset lifecycle: Active → Published → Archived → Deep Archive; restrict files via UI (Access → Files: Restricted), create new versions via UI, archive by setting record access to restricted and disabling edits.
- API tokens for ingest come from the UI under Account Settings → Applications → Tokens; reuse them for automation.

## MCP
- Repo template for Playwright MCP server: `.github/mcp-servers.playwright.example.json` (runs `npx -y @modelcontextprotocol/server-playwright` with Playwright browsers vendored via `PLAYWRIGHT_BROWSERS_PATH=0`). Copy/merge into your MCP client config before use; keep real secrets out of the repo.
