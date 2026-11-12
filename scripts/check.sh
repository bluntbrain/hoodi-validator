#!/usr/bin/env bash
# Lint everything that can be linted without a running node. CI runs the same script.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

echo "== docker compose config"
if [ -f .env ]; then envfile=.env; else envfile=.env.example; fi
docker compose --env-file "$envfile" config -q && echo ok || fail=1

echo "== yamllint"
if command -v yamllint >/dev/null; then
  yamllint -d '{extends: default, rules: {line-length: {max: 160}, document-start: disable, truthy: disable, comments-indentation: disable}}' \
    docker-compose.yml monitoring .github && echo ok || fail=1
else echo "skip (pip install yamllint)"; fi

echo "== shellcheck"
if command -v shellcheck >/dev/null; then
  shellcheck -S warning scripts/*.sh deploy/*.sh && echo ok || fail=1
else echo "skip (pip install shellcheck-py)"; fi

echo "== promtool"
if command -v promtool >/dev/null; then
  promtool check rules monitoring/prometheus/rules/*.yml || fail=1
  promtool check config monitoring/prometheus/prometheus.yml || fail=1
else echo "skip (promtool not installed; CI downloads it)"; fi

echo "== amtool"
if command -v amtool >/dev/null; then
  sed -e 's|\${TELEGRAM_BOT_TOKEN}|000:placeholder|' -e 's|\${TELEGRAM_CHAT_ID}|1|' \
    monitoring/alertmanager/alertmanager.yml.tmpl > /tmp/am-check.yml
  amtool check-config /tmp/am-check.yml || fail=1
else echo "skip (amtool not installed; CI downloads it)"; fi

echo "== grafana dashboard json"
python3 - <<'PY' || fail=1
import json, glob, sys
for f in glob.glob("monitoring/grafana/dashboards/*.json"):
    d = json.load(open(f))
    assert d.get("panels"), f"{f}: no panels"
    assert d.get("uid"), f"{f}: no uid"
    print(f"{f}: {len(d['panels'])} panels ok")
PY

exit $fail
