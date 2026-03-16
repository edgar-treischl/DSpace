#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env}"
COMPOSE_BIN="${COMPOSE:-docker compose}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-dspace}"
COMPOSE_CMD="$COMPOSE_BIN --project-name ${PROJECT_NAME} --env-file ${ENV_FILE}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

echo "Starting dependencies (db/search/cache/mq/minio)..."
$COMPOSE_CMD up -d db search cache mq minio

echo "Running database migration..."
$COMPOSE_CMD run --rm --entrypoint /dspace/bin/dspace web-api database migrate

echo "Creating/ensuring admin user..."
$COMPOSE_CMD run --rm --entrypoint /dspace/bin/dspace web-api create-administrator \
  -e "$DSPACE_ADMIN_EMAIL" \
  -f "${DSPACE_ADMIN_FIRST:-Admin}" \
  -l "${DSPACE_ADMIN_LAST:-User}" \
  -p "$DSPACE_ADMIN_PASSWORD" || true

echo "Building base community/collection structure..."
$COMPOSE_CMD run --rm --entrypoint /bin/sh web-api -c "cat >/tmp/dspace-structure.xml <<'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<import_structure>
  <community>
    <name>Demo Community</name>
    <short_description>Demo community</short_description>
    <collection>
      <name>Demo Collection</name>
      <short_description>Demo collection</short_description>
    </collection>
  </community>
</import_structure>
EOF
/dspace/bin/dspace structure-builder -f /tmp/dspace-structure.xml -e \"$DSPACE_ADMIN_EMAIL\" -o /tmp/structure.log && cat /tmp/structure.log"

echo "Rebuilding search index..."
$COMPOSE_CMD run --rm --entrypoint /dspace/bin/dspace web-api index-discovery || true

echo "Starting application services..."
$COMPOSE_CMD up -d web-api web-ui worker nginx

echo "Setup complete."
