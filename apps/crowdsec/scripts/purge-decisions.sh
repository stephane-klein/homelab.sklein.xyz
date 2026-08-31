#!/usr/bin/env bash
set -euo pipefail

NS="crowdsec"

echo "=== Purging expired CrowdSec decisions ==="
echo "  The LAPI never purges expired decisions from its SQLite DB. They bloat"
echo "  the DB and make the bouncer startup stream scan the whole backlog"
echo "  (crowdsecurity/crowdsec#4613), which breaks the bouncer sync and, with"
echo "  streamStartupBlock=true, blocks all traffic. Run this periodically."

kubectl -n "$NS" exec -i deploy/crowdsec-lapi -- sh -s <<'EOF'
set -e
command -v sqlite3 >/dev/null 2>&1 || apk add --no-cache sqlite >/dev/null 2>&1
DB=/var/lib/crowdsec/data/crowdsec.db
BEFORE=$(sqlite3 "$DB" "SELECT count(*) FROM decisions;")
ACTIVE=$(sqlite3 "$DB" "SELECT count(*) FROM decisions WHERE until > datetime('now','utc');")
sqlite3 "$DB" "DELETE FROM decisions WHERE until < datetime('now','utc');"
sqlite3 "$DB" "VACUUM;"
AFTER=$(sqlite3 "$DB" "SELECT count(*) FROM decisions;")
SIZE=$(du -h "$DB" | cut -f1)
echo "  decisions: $BEFORE -> $AFTER (active: $ACTIVE), db size: $SIZE"
EOF

echo "=== Done ==="