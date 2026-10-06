#!/bin/bash
# Migrations + demo sources, then api (localhost only), worker and web in one container; if one stops, the container stops
# and Railway restarts it. Secrets come from Railway variables; nothing is baked into the image.
set -eu
# Railway mounts volumes root-owned (seen with our n8n template, 2026-10-06): as root, give /data to node, then re-run as node.
if [ "$(id -u)" = "0" ]; then
  mkdir -p /data
  [ "$(stat -c %u /data)" = "1000" ] || chown -R 1000:1000 /data
  exec setpriv --reuid=1000 --regid=1000 --clear-groups env HOME=/home/node "$0" "$@"
fi
: "${DATABASE_URL:?DATABASE_URL missing (add the Railway PostgreSQL reference)}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD missing}"; : "${SESSION_SECRET:?SESSION_SECRET missing}"; : "${IMG_PROXY_SIGN_SECRET:?IMG_PROXY_SIGN_SECRET missing}"
[ "${#ADMIN_PASSWORD}" -ge 12 ] || { echo "ADMIN_PASSWORD must be at least 12 characters"; exit 1; }
export WEB_PORT="${PORT:-3000}"
if [ -z "${SITE_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then export SITE_URL="https://${RAILWAY_PUBLIC_DOMAIN}"; fi
node scripts/migrate.ts
[ -f /data/.seeded ] || { node scripts/seed.ts && touch /data/.seeded; }   # demo sources once, not on every restart
node apps/api/src/main.ts & API=$!
node apps/worker/src/main.ts & WORKER=$!
node apps/web/server.ts & WEB=$!
trap 'kill -TERM $API $WORKER $WEB 2>/dev/null' TERM INT
wait -n
echo "a process stopped - stopping the container so Railway restarts it"
kill -TERM $API $WORKER $WEB 2>/dev/null; wait
exit 1
