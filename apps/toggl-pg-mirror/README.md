# toggl-pg-mirror

[toggl-pg-mirror](https://github.com/stephane-klein/toggl-pg-mirror) mirrors
Toggl time-tracking data into the Memex PostgreSQL database via a periodic
sync daemon. Tables are stored in the `toggl` schema.

## Dependencies

This application depends on shared infrastructure deployed elsewhere:

- The `memex` CloudNativePG cluster (in the `memex` namespace) for PostgreSQL.
- The `external-secrets` operator and the `kubernetes-cnpg-memex`
  ClusterSecretStore, used to read the database credentials.
- The `toggl-api-token` Secret (created by the deploy script from Gopass).

## Deploy

```sh
$ mise run deploy-toggl-pg-mirror
```

The script waits for the external-secrets operator, ensures the
ClusterSecretStore, creates the `toggl-pg-mirror` namespace and the
`toggl-api-token` Secret from Gopass, then applies the local helmfile.

## Destroy

```sh
$ mise run destroy-toggl-pg-mirror
```

Runs `helmfile -f helmfile.yaml destroy` (scoped to this application only).

## URL

- App: https://toggl.sklein.internal
