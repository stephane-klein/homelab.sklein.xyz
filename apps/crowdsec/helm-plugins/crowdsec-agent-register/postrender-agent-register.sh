#!/usr/bin/env bash
# Helm 4 post-renderer for the CrowdSec release.
#
# The crowdsec/crowdsec chart hardcodes a NON-idempotent registration in the
# agent init container: `cscli lapi register --machine "$USERNAME"`. Because
# DaemonSet pod names are stable per node, on every pod recreation the machine
# already exists in LAPI and the register fails (403 "user already exist"),
# leaving the agent stuck in init BackOff.
#
# This post-renderer patches that init container command to be idempotent:
# it deletes the machine if it already exists, then registers it fresh.
set -euo pipefail

read -r -d '' PATCH_PY <<'PY' || true
import sys
import yaml

NEW_COMMAND = (
    'until nc "$LAPI_HOST" "$LAPI_PORT" -z; do echo waiting for lapi to start; '
    'sleep 5; done; ln -s /staging/etc/crowdsec /etc/crowdsec && '
    'cscli machines delete "$USERNAME" >/dev/null 2>&1 || true; '
    'cscli lapi register --machine "$USERNAME" -u "$LAPI_URL" '
    '--token "$REGISTRATION_TOKEN" && '
    'cp /etc/crowdsec/local_api_credentials.yaml /tmp_config/local_api_credentials.yaml'
)

def patch_doc(doc):
    if not isinstance(doc, dict):
        return doc
    if doc.get("kind") != "DaemonSet":
        return doc
    if doc.get("metadata", {}).get("name") != "crowdsec-agent":
        return doc
    init = doc.get("spec", {}).get("template", {}).get("spec", {}).get("initContainers", [])
    for c in init:
        if c.get("name") == "wait-for-lapi-and-register":
            cmd = c.get("command", [])
            if len(cmd) >= 3 and cmd[0] == "sh" and cmd[1] == "-c":
                cmd[2] = NEW_COMMAND
                c["command"] = cmd
    return doc

docs = list(yaml.safe_load_all(sys.stdin))
patched = [patch_doc(d) for d in docs]
yaml.safe_dump_all(patched, sys.stdout, default_flow_style=False, sort_keys=False, allow_unicode=True)
PY

python3 -c "$PATCH_PY"
