#!/bin/bash
# NAIVE deploy script — stop-then-start, has a real downtime gap between the
# `docker stop` and the new container passing its health check.
# Phase 9 replaces this with a true zero-downtime blue/green swap; keeping
# this version around in git history is deliberate so you can diff the two
# and see exactly what changed and why.
set -euo pipefail

IMAGE="$1"

docker pull "$IMAGE"
docker stop app 2>/dev/null || true
docker rm app 2>/dev/null || true
docker run -d --name app --restart unless-stopped -p 3000:3000 -e "APP_VERSION=$IMAGE" "$IMAGE"

echo "Deployed $IMAGE"
