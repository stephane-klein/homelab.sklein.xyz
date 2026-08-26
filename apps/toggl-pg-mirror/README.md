# toggl-pg-mirror

[toggl-pg-mirror](https://github.com/stephane-klein/toggl-pg-mirror) mirrors
Toggl time-tracking data into the Memex PostgreSQL database via a periodic
sync daemon. Tables are stored in the `toggl` schema.

## Dependencies

This application depends on shared infrastructure deployed elsewhere:

- The [`memex` CloudNativePG cluster](../databases/memex/README.md) (in the
  `memex` namespace) for PostgreSQL.
- The `external-secrets` operator and the `kubernetes-cnpg-memex`
  ClusterSecretStore, used to read the database credentials.
- The `toggl-pg-mirror` Secret (created by the deploy script from Gopass),
  holding three keys: `toggl-token`, `admin-token` and `smtp-password`.

## Deploy

```sh
$ mise run //apps/toggl-pg-mirror:deploy
```

The script waits for the external-secrets operator, ensures the
ClusterSecretStore, creates the `toggl-pg-mirror` namespace and the
`toggl-pg-mirror` Secret from Gopass, then applies the local helmfile.

## Destroy

```sh
$ mise run //apps/toggl-pg-mirror:destroy
```

Runs `helmfile -f helmfile.yaml destroy` (scoped to this application only).

## URL

- App: https://memex.ipv6.ingress.homelab.public.stephane-klein.info (et https://memex.sklein.xyz)
