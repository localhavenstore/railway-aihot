#!/usr/bin/env bash
# AIHOT Railway template: build + run in a FRESH throw-away VM the way Railway does (Dockerfile build, PostgreSQL, Railway-style
# variables, PORT), then: web answers, /admin requires the password, worker running, restart keeps data, no secret in the image.
set -uo pipefail
VM=${TESTVM:?set TESTVM to your throwaway-VM helper script}; H=$(cd "$(dirname "$0")" && pwd); OUT=$H/VM_TEST_RESULT.txt; : > "$OUT"
s() { "$VM" ssh "$1" >> "$OUT" 2>&1; echo "== $2 rc=$?" | tee -a "$OUT"; }
trap '"$VM" down >/dev/null 2>&1' EXIT
"$VM" up >> "$OUT" 2>&1 || exit 1
tar -C "$H" -czf /tmp/aihot-tpl-$$.tgz Dockerfile start.sh railway.toml && "$VM" put /tmp/aihot-tpl-$$.tgz /home/learner/tpl.tgz; rm -f /tmp/aihot-tpl-$$.tgz
s "sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io docker-buildx curl >/dev/null && mkdir -p tpl && tar -xzf tpl.tgz -C tpl && sudo docker version --format '{{.Server.Version}}'" prereq
s "cd tpl && sudo DOCKER_BUILDKIT=1 docker build -t aihot-tpl . 2>&1 | grep -E 'pinned|ERROR|error:' | tail -5; sudo docker image inspect aihot-tpl --format 'image ok {{.Size}}'" build
s "sudo docker network create t && sudo docker run -d --name db --network t -e POSTGRES_USER=aihot -e POSTGRES_PASSWORD=dbpw-test-123 -e POSTGRES_DB=aihot postgres:17-alpine >/dev/null && sleep 8 && echo db-up" db
ENV='-e DATABASE_URL=postgres://aihot:dbpw-test-123@db:5432/aihot -e ADMIN_PASSWORD=admin-pw-test-1234 -e SESSION_SECRET=s1s1s1s1s1s1s1s1s1s1s1s1s1s1s1s1 -e IMG_PROXY_SIGN_SECRET=i1i1i1i1i1i1i1i1i1i1i1i1i1i1i1i1 -e LLM_BASE_URL=http://127.0.0.1:9/v1 -e LLM_API_KEY=test-not-real -e LLM_MODEL=test -e PORT=8080 -e RAILWAY_PUBLIC_DOMAIN=example.test'
s "sudo install -d -o root -g root -m 0755 /home/learner/aihotvol && sudo docker run -d --name app --network t -p 127.0.0.1:8080:8080 -v /home/learner/aihotvol:/data $ENV aihot-tpl >/dev/null; for i in \$(seq 1 60); do curl -fs -o /dev/null http://127.0.0.1:8080/ && break; sleep 3; done; curl -s -o /dev/null -w 'web %{http_code}\n' http://127.0.0.1:8080/; sudo docker logs app 2>&1 | tail -15 | cut -c1-200" run
s "curl -s -o /dev/null -w 'admin %{http_code} -> %{redirect_url}\n' http://127.0.0.1:8080/admin; curl -s http://127.0.0.1:8080/admin | grep -o -i -E 'password|login|密码' | head -2; sudo docker exec app sh -c 'ps -eo args | grep -E \"apps/(api|worker|web)\" | grep -v grep | cut -c1-60'; sudo docker exec app sh -c 'curl -s -o /dev/null -w \"api-local %{http_code}\n\" http://127.0.0.1:3001/ 2>/dev/null || node -e \"fetch(\\\"http://127.0.0.1:3001/\\\").then(r=>console.log(\\\"api-local\\\",r.status)).catch(e=>console.log(\\\"api err\\\",e.message))\"'" checks
s "sudo docker restart app >/dev/null; for i in \$(seq 1 60); do curl -fs -o /dev/null http://127.0.0.1:8080/ && break; sleep 3; done; curl -s -o /dev/null -w 'after-restart web %{http_code}\n' http://127.0.0.1:8080/; sudo docker exec app ls -la /data | head -5; sudo docker top app -o pid,uid,args | head -6 | cut -c1-80; echo seed-runs=\$(sudo docker logs app 2>&1 | grep -c 'sources: [0-9]* added')" restart
s "sudo docker history --no-trunc aihot-tpl | grep -c -E 'admin-pw-test|dbpw-test|test-not-real' || true; sudo docker exec app env | grep -c -E 'admin-pw-test' " secrets
echo "done $(date -Is)" >> "$OUT"
