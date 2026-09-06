# Managed databases

Index of the PostgreSQL databases managed in this homelab, all provisioned by
the [CloudNativePG](https://cloudnative-pg.io/) operator (`cnpg-system`
namespace, `mise run deploy-cnpg`).

## General rule: `databases/<db>/`

Each **shared/autonomous** database lives in its own self-contained directory
under `databases/<db>/` (helmfile, values, deploy/destroy scripts, mise tasks
namespaced `//databases/<db>:<task>`, README). Secrets such as S3 backup
credentials are created by `scripts/deploy.sh` with `kubectl create secret`
after `helmfile apply` (so Helm does not delete them on upgrade).

| Database | Node | Purpose | Backup |
|---|---|---|---|
| [`memex`](./memex/) | `nuc-i3-gen5` | backs https://memex.sklein.xyz | CNPG nightly S3 (`homelab-cnpg-backups/memex/`, 30 d) |

> **Legacy:** the `hindsight-cnpg-cluster` (Hindsight's ParadeDB) is not yet
> migrated out of the monolithic `helmfile/helmfile.yaml.gotmpl`; it will move
> to `databases/` (or into `apps/hindsight/`) when Hindsight is refactored.

## Exception: app-private databases in `apps/<app>/`

A database that is an **internal detail of a single app** is colocated inside
that app's self-contained directory instead of under `databases/` — the
database is not a shared resource, so it does not get its own top-level
directory.

Today the only case is **Forgejo** (see `apps/forgejo/README.md`): its CNPG
cluster (`forgejo-cluster`, namespace `forgejo`, node `nuc-i7-gen11`) is
declared as the first release of `apps/forgejo/helmfile.yaml`, with backup and
ops scripts under `apps/forgejo/scripts/`. Forgejo's git repositories are
backed up weekly by a CronJob, see `apps/forgejo/backup/cronjob-backup.yaml`.

If a database starts being shared by several apps, migrate it into a
`databases/<db>/` directory (as was done for `memex`).
