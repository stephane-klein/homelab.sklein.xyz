# CrowdSec

[CrowdSec](https://www.crowdsec.net/) protects the **public** Traefik ingress
(`traefik-public`, IPv6 `::1000`) from malicious traffic. It runs as a k3s
workload in the `crowdsec` namespace ([LAPI](#terminology) + agent) and blocks
requests by IP reputation.

## Terminology

- **LAPI** (Local API) — the CrowdSec local API that stores decisions and
  serves bouncers. See [CrowdSec docs](https://docs.crowdsec.net/docs/local_api/intro/).
- **CAPI** (Central API) — the CrowdSec cloud API providing the community
  blocklist and signal sharing. See [CrowdSec docs](https://docs.crowdsec.net/docs/central_api/intro/).

## How it works

- The **agent** (DaemonSet) reads the access logs of the `traefik-public` pod
  (`agent.acquisition` in `values.yaml`).
- The **[LAPI](https://docs.crowdsec.net/docs/local_api/intro/)** analyses those logs and produces IP **decisions** (ban).
- **traefik-public** runs the CrowdSec bouncer as a Traefik **plugin** in
  **stream mode** (decision cache refreshed every 60 s). The middleware is
  attached **globally** to the `websecure` entrypoint via the file provider, so
  every public request is checked without touching each Ingress.

> **Agent registration is patched to be idempotent.** The upstream chart's
> `wait-for-lapi-and-register` init container does a non-idempotent
> `cscli lapi register --machine "$USERNAME"`, which fails (403 "already exist")
> on pod recreation because DaemonSet pod names are stable per node, leaving the
> agent stuck in init BackOff. A Helm 4 post-renderer plugin
> (`helm-plugins/crowdsec-agent-register`) rewrites that command to delete an
> existing machine before registering. `scripts/deploy.sh` installs the plugin
> automatically if missing.

## Deploy

Order matters: CrowdSec first (so we can generate the key), then Traefik.

The agent analyses the **access logs** of `traefik-public`. These are enabled by
`scripts/deploy-traefik-public.sh` (`--accesslog=true --accesslog.format=json`,
written to stdout). Redeploying `traefik-public` restarts the pod and activates
them.

```sh
$ mise run //apps/crowdsec:deploy
```

This also provisions the **blocklist-import** CronJob (see
[Blocklist import](#blocklist-import) below), registering the LAPI machine and
bouncer in gopass on first run.

Generate the bouncer key and store it in gopass:

```sh
$ kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli bouncers add traefik-bouncer
# -> returns a key; store it in gopass:
$ gopass insert homelab/crowdsec/bouncer-key
```

Then deploy/refresh the public Traefik with the bouncer plugin:

```sh
$ mise run deploy-traefik-public
```

## Test

Ban an IP and check it is blocked, then unban:

```sh
$ kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli decisions add --ip <ip> -d 5m
$ curl -6 --resolve whoami.ipv6.ingress.homelab.public.stephane-klein.info:443:<your-ipv6> https://...
# expected: HTTP 403 while banned
$ kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli decisions remove --ip <ip>
```

See also `cscli decisions list` and `cscli bouncers list`.

## Status

Display the current CrowdSec state (registered bouncers, active decisions,
recent alerts, LAPI/stream metrics and Traefik log ingestion):

```sh
$ mise run //apps/crowdsec:status
```

## Blocklist import

The `blocklist-import` **CronJob** runs
[wolffcatskyy/crowdsec-blocklist-import](https://github.com/wolffcatskyy/crowdsec-blocklist-import)
every 6 h. It imports free external threat-intelligence feeds into the LAPI
(in addition to the community blocklist via [CAPI](https://docs.crowdsec.net/docs/central_api/intro/)), which the public Traefik
bouncer then enforces. This avoids the paid console blocklists.

- **Config** (feeds, decision defaults): `blocklist-import.yaml` (ConfigMap `blocklist-import-config`).
- **Credentials**: a LAPI machine + bouncer, registered automatically on first
  deploy and stored in gopass (`homelab/crowdsec/blocklist-import/*`), injected
  via the `blocklist-import-credentials` Secret (`_FILE` env, never inline).
- **Feed subset by default**: all major feeds enabled — Spamhaus DROP, abuse.ch,
  Blocklist.de, Emerging Threats, IPsum and FireHOL. The active set stays
  manageable because `MAX_DECISIONS` caps it and the purge-before-import keeps
  the expired-decisions backlog bounded (the backlog, not the active count, is
  what broke the bouncer sync — see [Maintenance](#maintenance)). Tor, scanners,
  StopForumSpam and the other large/aggressive feeds remain disabled. Toggle via
  `ENABLE_*`.
- **The owner's own IPs are deliberately NOT allowlisted** — a future block
  (e.g. a feed range covering them) is immediately visible instead of silently
  masked. If it happens, remove the decision and run `mise run
  //apps/crowdsec:purge`.
- **`MAX_DECISIONS=80000`** caps the total number of decisions, keeping the LAPI
  SQLite datastore responsive (high enough for IPsum + FireHOL to be actually
  imported; the current active set is ~55k decisions).
- **Safe before enabling for real**: set `DRY_RUN: "true"` in the ConfigMap,
  create a one-off Job and check the logs, then revert.

Check the import status (number of imported decisions + CronJob state):

```sh
$ mise run //apps/crowdsec:blocklist-import:status
```

Force an immediate run of the CronJob (e.g. after changing the feeds) and
watch its logs:

```sh
$ mise run //apps/crowdsec:blocklist-import:run
```

## Maintenance

The LAPI never purges expired decisions from its SQLite database. They
accumulate with each `blocklist-import` run, bloat the DB, and eventually make
the bouncer startup stream scan the whole backlog (see
[crowdsecurity/crowdsec#4613](https://github.com/crowdsecurity/crowdsec/issues/4613)),
which breaks the bouncer sync and — with `streamStartupBlock: true` — blocks all
traffic with HTTP 403.

**The purge runs automatically before every `blocklist-import` run**: an
initContainer (`blocklist-import.yaml`, ServiceAccount `crowdsec-purge`) deletes
the expired rows via `kubectl exec` into the LAPI pod (the PVC is RWO, so the
purge must run inside the pod). It does not `VACUUM` — that would lock the DB
and disrupt the bouncer sync.

Compact the database file occasionally (frees disk space; the purge-before-import
already keeps the row count bounded):

```sh
$ mise run //apps/crowdsec:purge
```

Run it e.g. monthly or as soon as the DB grows. It only removes decisions whose
expiration (`until`) is already in the past; active decisions are untouched.

## Destroy

> Destructive: wipes LAPI decisions, the bouncer key, and the blocklist-import
> CronJob/ConfigMap/Secret. Requires explicit confirmation before running
> (project safety rule).

```sh
$ mise run //apps/crowdsec:destroy
```

## Dependencies

- Depends on the `traefik-public` release deployed by
  `scripts/deploy-traefik-public.sh` (this script provisions the
  `crowdsec-bouncer-key` secret and the `crowdsec-dynamic` ConfigMap from
  `config/traefik-public/`).
- Real client IPs are preserved because `traefik-public` binds directly on the
  public IPv6 (`hostNetwork`, no NAT on the BBox) — no `forwardedHeaders` needed.
