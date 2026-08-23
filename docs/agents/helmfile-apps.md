# Per-application Helmfile deployment

Operational snapshot of how applications are deployed in this homelab. See
[`../decisions/2026-08_001-per-app-helmfile-directories.md`](../decisions/2026-08_001-per-app-helmfile-directories.md)
for the rationale (ADR 001).

## Layout

Each application lives in its own directory `apps/<app>/`:

- `helmfile.yaml` — the single Helm release for the app (chart, namespace, values)
- `values.yaml` — Helm values
- `scripts/deploy.sh` — create namespace/secrets from Gopass, then `helmfile apply`
- `scripts/destroy.sh` — `helmfile destroy`
- `.mise.toml` — short-named tasks (`deploy`, `destroy`, `diff`, …)
- `README.md` — deployment instructions and dependencies

## Deploy workflow

The root `.mise.toml` enables mise monorepo mode (`monorepo_root = true`), so app
tasks live in each app's `.mise.toml` and are namespaced as
`//apps/<app>:<task>`. `scripts/deploy.sh` is run via `mise run //apps/<app>:deploy`
(e.g. `mise run //apps/toggl-pg-mirror:deploy`, or from inside the app with
`mise :deploy`):

1. `cd "$(dirname "$0")/../"`
2. Ensure the namespace exists (`kubectl create namespace ... --dry-run=client -o yaml | kubectl apply -f -`)
3. Create secrets from Gopass with `kubectl create secret generic ... --from-literal=...` (secrets cannot be created declaratively by Helmfile)
4. `helmfile -f helmfile.yaml apply`

`scripts/destroy.sh` runs `helmfile -f helmfile.yaml destroy`. Because each
helmfile contains only its own app, destroy is naturally scoped — no
`--selector name=` needed.

## Gotchas

- Each app directory generates its own `.helmfile/` state directory (gitignored).
- The `repositories:` block is declared per app (duplicated across apps).
- Apps can depend on shared infrastructure deployed elsewhere (e.g.
  toggl-pg-mirror writes to the `memex` CNPG cluster and reads DB credentials
  via external-secrets from the `kubernetes-cnpg-memex` ClusterSecretStore).
  Document such dependencies in the app README.
- Legacy services not yet migrated still use the global
  `helmfile/helmfile.yaml.gotmpl`.
