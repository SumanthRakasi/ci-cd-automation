#!/bin/bash
# Zero-downtime blue/green swap. Both the old and new app containers run
# simultaneously for a moment; Nginx only points at the new one once it's
# confirmed healthy, and the old one is retired only after that.
set -euo pipefail

IMAGE="$1"
UPSTREAM_CONF=/home/ec2-user/nginx/conf.d/upstream.conf
HEALTH_RETRIES=15
HEALTH_DELAY=2

CURRENT_PORT=$(grep -oP '127\.0\.0\.1:\K[0-9]+' "$UPSTREAM_CONF")
if [ "$CURRENT_PORT" = "3000" ]; then
  NEW_PORT=3001
else
  NEW_PORT=3000
fi

NEW_NAME="app-${NEW_PORT}"
OLD_NAME="app-${CURRENT_PORT}"

echo "Current live: $OLD_NAME (port $CURRENT_PORT)"
echo "Deploying to standby: $NEW_NAME (port $NEW_PORT)"

docker pull "$IMAGE"

docker rm -f "$NEW_NAME" 2>/dev/null || true
docker run -d --name "$NEW_NAME" --restart unless-stopped \
  -p "${NEW_PORT}:3000" -e "APP_VERSION=$IMAGE" "$IMAGE"

echo "Waiting for $NEW_NAME to become healthy..."
healthy=false
for i in $(seq 1 $HEALTH_RETRIES); do
  if curl -sf "http://127.0.0.1:${NEW_PORT}/health" > /dev/null; then
    echo "Healthy after $((i * HEALTH_DELAY))s."
    healthy=true
    break
  fi
  sleep $HEALTH_DELAY
done

if [ "$healthy" != "true" ]; then
  echo "New container never became healthy -- aborting deploy, leaving $OLD_NAME live." >&2
  docker rm -f "$NEW_NAME" || true
  exit 1
fi

# The actual traffic switch: rewrite the upstream Nginx reads, then reload.
cat > "$UPSTREAM_CONF" <<EOF2
upstream app_backend {
    server 127.0.0.1:${NEW_PORT};
}
EOF2
docker exec nginx nginx -s reload
echo "Traffic switched to $NEW_NAME."

docker stop "$OLD_NAME" 2>/dev/null || true
docker rm "$OLD_NAME" 2>/dev/null || true

echo "Deployed $IMAGE (zero-downtime swap complete)."
