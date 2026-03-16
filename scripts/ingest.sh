#!/usr/bin/env bash
set -euo pipefail

TOKEN_ARG=""; ENV_FILE=".env"
for arg in "$@"; do
  case "$arg" in
    token=*) TOKEN_ARG="${arg#token=}" ;;
    env_file=*) ENV_FILE="${arg#env_file=}" ;;
  esac
done

COMPOSE_BIN="${COMPOSE:-docker compose}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-dspace}"
COMPOSE_CMD="$COMPOSE_BIN --project-name ${PROJECT_NAME} --env-file ${ENV_FILE}"

if [[ -z "$TOKEN_ARG" ]]; then
  echo "Usage: $0 token=<api-token> [env_file=.env]" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -d "datasets/iris" ]]; then
  echo "Missing dataset directory: datasets/iris" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

WORKDIR="$(mktemp -d)"
ITEM_DIR="${WORKDIR}/item_000"
mkdir -p "$ITEM_DIR"

cp datasets/iris/data.csv "$ITEM_DIR"/
cp datasets/iris/schema.json "$ITEM_DIR"/
cp datasets/iris/metadata.json "$ITEM_DIR"/
cp datasets/iris/README.md "$ITEM_DIR"/

cat > "$ITEM_DIR/contents" <<'EOF'
data.csv
schema.json
metadata.json
README.md
EOF

cat > "$ITEM_DIR/dublin_core.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<dublin_core schema="dc">
  <dcvalue element="title" qualifier="none">Iris flower dataset (demo)</dcvalue>
  <dcvalue element="creator" qualifier="none">R. A. Fisher</dcvalue>
  <dcvalue element="subject" qualifier="none">Machine learning</dcvalue>
  <dcvalue element="description" qualifier="abstract">Benchmark iris dataset packaged as a DSpace demo item.</dcvalue>
  <dcvalue element="rights" qualifier="none">CC0-1.0</dcvalue>
</dublin_core>
EOF

echo "Copying SAF package into web-api container..."
$COMPOSE_CMD cp "$ITEM_DIR" web-api:/tmp/iris-ingest

echo "Importing dataset into DSpace collection ${DSPACE_COLLECTION_HANDLE}..."
$COMPOSE_CMD exec web-api /dspace/bin/dspace import \
  --add \
  --eperson="$DSPACE_ADMIN_EMAIL" \
  --collection="$DSPACE_COLLECTION_HANDLE" \
  --source=/tmp/iris-ingest \
  --mapfile=/tmp/iris-ingest/mapfile

echo "Refreshing discovery index..."
$COMPOSE_CMD exec web-api /dspace/bin/dspace index-discovery || true

rm -rf "$WORKDIR"
echo "Ingest complete. Token ${TOKEN_ARG} was provided for auditing; CLI ingest used admin credentials."
