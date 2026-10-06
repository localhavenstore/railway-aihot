# Railway template: AIHOT engine (github.com/KKKKhazix/AIHOT, MIT) pinned to a tested commit. One container runs web + api + worker
# (Railway volumes attach to one service only, and api + worker share /data). Database = Railway PostgreSQL (DATABASE_URL).
FROM node:24-trixie-slim AS src
ARG AIHOT_COMMIT=2b80294859160a727e0749f7b8b6232c2812fdf4
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates && rm -rf /var/lib/apt/lists/* \
 && git clone --filter=blob:none https://github.com/KKKKhazix/AIHOT.git /src && cd /src && git checkout --detach "$AIHOT_COMMIT" \
 && git log -1 --format='pinned %H %cI' && rm -rf /src/.git

FROM node:24-trixie-slim AS build
WORKDIR /app
COPY --from=src /src /app
RUN npm ci --no-audit --no-fund && npm run build -w @aihot/web && npm prune --omit=dev --no-audit --no-fund

FROM node:24-trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client ca-certificates tini && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production AIHOT_DATA_DIR=/data API_HOST=127.0.0.1 API_PORT=3001 API_BASE_URL=http://127.0.0.1:3001 WEB_HOST=0.0.0.0 TRUST_PROXY=true
COPY --from=build --chown=node:node /app /app
COPY --chown=node:node start.sh /app/start.sh
RUN mkdir -p /data && chown node:node /data && chmod 0755 /app/start.sh
WORKDIR /app
# starts as root ONLY to give the volume (/data, root-owned on Railway) to user node; start.sh then drops to node via setpriv
EXPOSE 3000
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/start.sh"]
