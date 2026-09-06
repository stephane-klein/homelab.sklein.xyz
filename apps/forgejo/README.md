# Forgejo

Self-hosted Git forge ([Forgejo](https://forgejo.org/), the community fork of
Gitea) with its **private** CloudNativePG PostgreSQL database, deployed on the
internal (Netbird VPN) ingress only:

- URL: `https://forgejo.sklein.internal` (TLS from the private `homelab-ca` CA)
- Git over SSH: `ssh://git@forgejo.sklein.internal:32222/...` (Netbird VPN only,
  via the internal Traefik TCP entrypoint `ssh` — see the SSH section below).
- Auth: Forgejo manages its own accounts/tokens/SSH keys — **not** behind
  Authelia (programmatic clients: git clone, package/container registry, API).
- Node: pinned to `nuc-i7-gen11.homelab.stephane-klein.info` (`nodeSelector` in
  `values.yaml`); its `local-path` PVCs (`forgejo-data`, CNPG volume) live on
  this node's disk.
- Exposed features: git over HTTPS and SSH, plus Forgejo's integrated container
  & package registries and Actions (CI — see [the runner](runner/README.md)).

## Layout

Everything lives in this one self-contained directory (ADR 001 pattern), **the
database included** — see `databases/README.md` for why this app is the
exception to the `databases/<db>/` convention:

- `helmfile.yaml` — two releases, applied in order:
  1. `forgejo-cluster` — CNPG PostgreSQL 18 cluster (`cnpg/cluster` chart,
     version `0.7.0`). Helm release name `forgejo-cluster` → Cluster CR
     `forgejo-cluster`, services `forgejo-cluster-rw/ro/r`.
  2. `forgejo` — the official `forgejo-helm` chart (OCI, version `17.1.5`).
- `values.yaml` — single values file shared by both releases (each chart
  ignores the keys of the other).
- `scripts/` — deploy / destroy / diff + CNPG operations.
- `backup/cronjob-backup.yaml` — weekly S3 backup of the `forgejo-data` volume.
- `ssh/ingress-route-tcp.yaml` — Traefik `IngressRouteTCP` exposing git over
  SSH through the internal Traefik `ssh` entrypoint.
- `scripts/container-registry-token.sh` — create/refresh the container-registry
  token (see the Container registry section).
- `runner/` — the **Forgejo Actions runner** (CI), deployed as an LXC instance
  on incus-server1 (see [`runner/README.md`](runner/README.md)).

## Dependencies

- Shared infrastructure deployed elsewhere:
  - CloudNativePG operator (`cnpg-system` namespace, `mise run deploy-cnpg`).
  - `cert-manager` + the `homelab-ca` ClusterIssuer (Ingress TLS).
  - `traefik` (internal ingress controller, `traefik` ingressClass), including
    the TCP `ssh` entrypoint (see the SSH section below).
  - Scaleway Object Storage bucket `homelab-forgejo-backups` (DB + data backups).
- Gopass secrets (source of truth):
  - `homelab/forgejo/admin/username` — admin login
  - `homelab/forgejo/admin/password` — admin password
  - `homelab/forgejo/container-registry-token` — container-registry token
    (scopes `read:package,write:package`, see the Container registry section)
  - `homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY` and
    `homelab/scaleway/CNPG_BACKUPS_SECRET_KEY` — S3 backup credentials

## Deploy

```sh
$ mise run //apps/forgejo:deploy
```

The script ensures the `forgejo` namespace, creates the `forgejo-admin-secret`
(idempotent) and the S3 backup credentials Secret from Gopass, runs
`helmfile apply` (DB first, then the app), and installs the weekly data-backup
CronJob. Forgejo reads its DB password from the CNPG-generated
`forgejo-cluster-app` Secret (see `values.yaml`,
`gitea.additionalConfigFromEnvs`).

The initial admin user is created at first boot from `forgejo-admin-secret`
(`passwordMode: initialOnlyNoReset` — the password is only set on creation and
can then be changed from the UI without being reset on the next rollout).

## Git over SSH

Forgejo serves git over SSH at `ssh://git@forgejo.sklein.internal:32222/...`,
exposed **on the Netbird VPN only** (never on the public IPv6):

- Forgejo's internal SSH server listens on `2222` (rootless image,
  `SSH_LISTEN_PORT`), behind the ClusterIP service `forgejo-ssh:22`.
- The internal Traefik exposes a TCP entrypoint `ssh` bound on the Netbird IP
  `100.91.106.71:32222` (added by `scripts/deploy-traefik.sh`,
  `additionalArguments[5]`).
- `ssh/ingress-route-tcp.yaml` routes that entrypoint to the `forgejo-ssh`
  service. It is applied by `scripts/deploy.sh`.

**Prerequisite — enable the Traefik entrypoint once:**

```sh
$ ./scripts/deploy-traefik.sh   # adds entryPoints.ssh on ${NETBIRD_IP}:32222
```

Then `mise run //apps/forgejo:deploy`.

Clone URLs advertised by Forgejo use `SSH_PORT: 32222` and `SSH_DOMAIN`
= `forgejo.sklein.internal` (auto-derived from the ingress). Add your public
key in the Forgejo UI (Settings → SSH / GPG Keys) before cloning.

## Database operations

```sh
$ mise run //apps/forgejo:list-backups
$ mise run //apps/forgejo:backup
$ mise run //apps/forgejo:delete-backup <backup-name>
$ mise run //apps/forgejo:enter-in-postgres
```

The CNPG cluster runs a nightly barman S3 backup
(`homelab-forgejo-backups/forgejo/`, 30-day retention).

## Data backups

- **Database**: CNPG nightly S3 backup (see above).
- **Volume** (`/data` of the Forgejo pod: git repositories, LFS, avatars,
  config): weekly CronJob `forgejo-data-backup` (Sunday 02:30 Europe/Paris)
  tars the `forgejo-data` PVC and uploads it to
  `s3://homelab-forgejo-backups/forgejo-data/` (30-day purge). Trigger a run
  manually with:

  ```sh
  $ kubectl create job --from=cronjob/forgejo-data-backup forgejo-data-backup-manual -n forgejo
  ```

## Usage

```sh
$ git clone https://forgejo.sklein.internal/<user>/<repo>.git
$ git clone ssh://git@forgejo.sklein.internal:32222/<user>/<repo>.git
```

## Container registry

Forgejo hosts a private OCI container registry at
`forgejo.sklein.internal` (the docker-registry `registry.sklein.internal` has
been replaced by it). Images live under an owner namespace:
`forgejo.sklein.internal/stephane-klein/<image>:<tag>`.

- **Registry is private** (`GET /v2/...` returns 401 without credentials).
- Push/pull from a workstation requires the account password or a personal
  access token. A dedicated token is stored in Gopass at
  `homelab/forgejo/container-registry-token` (scopes `read:package`,
  `write:package`):

```sh
$ mise run //apps/forgejo:container-registry-token   # create/refresh token
$ TOKEN=$(gopass show -o homelab/forgejo/container-registry-token)
$ echo "$TOKEN" | podman login forgejo.sklein.internal -u stephane-klein --password-stdin
$ podman build -t forgejo.sklein.internal/stephane-klein/<image>:<tag> .
$ podman push forgejo.sklein.internal/stephane-klein/<image>:<tag>
```

- **k3s node pull auth**: the two nodes authenticate at the containerd level
  via `/etc/rancher/k3s/registries.yaml`, so workloads can reference
  `forgejo.sklein.internal/stephane-klein/<image>:<tag>` with no
  `imagePullSecrets`:

```sh
$ ./scripts/configure-k3s-registry.sh
```

The script copies the homelab CA to each node, writes `registries.yaml` with
the `stephane-klein` credentials (from
`homelab/forgejo/container-registry-token`), and restarts `k3s` /
`k3s-agent` (short downtime). It is idempotent and re-runnable.

In a workload, reference the full image name and use `imagePullPolicy: Always`
(or unique tags per push) — otherwise containerd serves the locally cached
image and you deploy a stale build.

## Destroy

```sh
$ mise run //apps/forgejo:destroy
```

Destroys both Helm releases, the data-backup CronJob and the SSH
`IngressRouteTCP`. Note that the Forgejo chart sets
`helm.sh/resource-policy: keep` on its PVC, so `forgejo-data` may survive —
remove it manually if the data must go. Run this only after confirming the
backups on S3. The Traefik `ssh` entrypoint itself is left in place (it is
shared infrastructure managed by `scripts/deploy-traefik.sh`).

## CI (Forgejo Actions)

Forgejo ships its own Actions CI (enabled by default). Jobs run on a **runner
LXC instance** (`forgejo-runner1`) hosted on `incus-server1` — deliberately
**outside** the k3s cluster to isolate CI builds. It uses **podman** to execute
jobs and joins the Netbird `incus` group to reach `forgejo.sklein.internal`.

See **[`runner/README.md`](runner/README.md)** for the full design, the image
build, and the deployment/operations commands.
