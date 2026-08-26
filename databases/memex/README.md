# memex

CloudNativePG PostgreSQL cluster backing the Memex knowledge database
(https://memex.sklein.xyz). Runs on `nuc-i3-gen5` with S3 backups to Scaleway
(`homelab-cnpg-backups/memex/`, 30-day retention, nightly).

## Dependencies

- The CloudNativePG operator (`cnpg-system` namespace, deployed via
  `mise run deploy-cnpg`).
- `homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY` and
  `homelab/scaleway/CNPG_BACKUPS_SECRET_KEY` in Gopass, used to create the
  `memex-cluster-backup-s3-creds` Secret.

## Deploy

```sh
$ mise run //databases/memex:deploy
```

The script ensures the `memex` namespace, applies the local helmfile, then
creates the S3 backup credentials Secret (idempotent) from Gopass. The
secret is created after `helmfile apply` so Helm does not delete it on upgrade.

## Destroy

```sh
$ mise run //databases/memex:destroy
```

Runs `helmfile -f helmfile.yaml destroy` (scoped to this database only).

## Operations

```sh
$ mise run //databases/memex:list-backups
$ mise run //databases/memex:backup
$ mise run //databases/memex:delete-backup <backup-name>
$ mise run //databases/memex:diff
```

Connect:

```sh
$ kubectl get secret memex-cluster-memex -n memex -o jsonpath='{.data.password}' | base64 -d
$ kubectl cnpg psql memex-cluster -n memex
```
