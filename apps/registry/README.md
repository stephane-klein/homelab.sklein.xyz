# Private container registry

[registry:2](https://distribution.github.io/distribution/) (OCI distribution)
served by the `twuni/docker-registry` Helm chart, exposed on the **internal**
(Netbird VPN) ingress only:

- URL: `https://registry.sklein.internal` (TLS from the private `homelab-ca` CA)
- Auth: HTTP basic auth (htpasswd, bcrypt) — **not** behind Authelia, because
  push/pull clients are programmatic.
- Accessible from every Netbird peer in the `homelab_servers`, `user_devices`
  and `dev_devices` groups (wildcard `*.sklein.internal` Netbird DNS record).
- Node: pinned to `nuc-i7-gen11.homelab.stephane-klein.info` (`nodeSelector` in
  `values.yaml`); its `local-path` PVC (`docker-registry`) lives on this node's
  disk — images and the registry pod are bound to this node.

## Dependencies

- Shared infrastructure deployed elsewhere:
  - `cert-manager` + the `homelab-ca` ClusterIssuer (TLS certificate for the
    Ingress).
  - `traefik` (internal ingress controller, `traefik` ingressClass).
- Gopass secrets (one entry per registry user):
  - `homelab/registry/<user>/password` — plaintext password (used by
    containerd on the nodes and by `podman login`).
  - `homelab/registry/<user>/htpasswd` — bcrypt line `user:$2y$...` (served by
    the registry to authenticate push/pull).

Only `stephane` exists today. Add a user by extending the `REGISTRY_USERS`
list in `scripts/deploy.sh` and creating the two Gopass entries.

## Deploy

```sh
$ mise run //apps/registry:deploy
```

This reads the htpasswd content from Gopass, sets `REGISTRY_HTPASSWD` and runs
`helmfile -f helmfile.yaml.gotmpl apply` (namespace `registry`).

## Node pull configuration (containerd)

The two k3s nodes authenticate against the registry at the containerd level
(`/etc/rancher/k3s/registries.yaml`), so workloads can reference
`registry.sklein.internal/<image>:<tag>` with no `imagePullSecrets`:

```sh
$ ./scripts/configure-k3s-registry.sh
```

The script copies the homelab CA to each node, writes `registries.yaml` with
the `stephane` credentials, and restarts `k3s` / `k3s-agent` (short downtime).
It is idempotent and re-runnable (also after a node reprovision).

## Usage

```sh
$ podman login registry.sklein.internal          # user: stephane
$ podman build -t registry.sklein.internal/my-app:dev .
$ podman push registry.sklein.internal/my-app:dev
```

In a workload, reference the full image name and use `imagePullPolicy: Always`
(or unique tags per push) — otherwise containerd serves the locally cached
image and you deploy a stale build. The nightly `k3s crictl rmi --prune` only
touches the node-local cache, never the registry storage (PVC).

Verify the registry answers (401 without credentials):
```sh
$ curl -sI https://registry.sklein.internal/v2/
```

### Listing images

List the repositories (one per line) or the tags of a given repository:

```sh
$ mise run //apps/registry:list-images
$ mise run //apps/registry:list-tags -- whoami
```

## Destroy

```sh
$ mise run //apps/registry:destroy
```

This removes the Helm release (and the PVC, i.e. all stored images). It does
**not** remove the node-level `registries.yaml` config — run
`./scripts/configure-k3s-registry.sh` equivalent cleanup if the registry is
not meant to come back.

## Backup

**No backup system is installed** for the registry storage (the
`docker-registry` PVC on `nuc-i7-gen11`). This is an accepted trade-off: every
image is assumed to be **rebuildable** from its source (git / Dockerfile / CI),
so a lost PVC only costs a rebuild.

If that assumption stops holding, a backup to Object Storage (e.g. Scaleway S3)
could be added later — for instance periodic blob export/replication, or
migrating to a registry with built-in replication such as Harbor.

## Maintenance

Garbage collection is **disabled** in the chart (its CronJob cannot be pinned
to the node hosting the local-path PVC). Run GC manually when the storage
grows:

```sh
$ kubectl -n registry exec deploy/docker-registry -- \
    registry garbage-collect /etc/distribution/config.yml --delete-untagged
```

### Rotating a password

1. Update the Gopass entries for the user (`password` and `htpasswd`,
   regenerated with `htpasswd -Bni <user>`).
2. Re-run `mise run //apps/registry:deploy` (rolls the registry pod).
3. Re-run `./scripts/configure-k3s-registry.sh` (updates the node credentials).
