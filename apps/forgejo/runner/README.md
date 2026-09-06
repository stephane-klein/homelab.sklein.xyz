# Forgejo Actions runner

The [Forgejo Actions](https://forgejo.org/docs/latest/user/actions/overview/)
runner executes CI workflows (`.forgejo/workflows/*.yml`) for the self-hosted
Forgejo at https://forgejo.sklein.internal.

Unlike the other workloads of this repo, the runner is **not** a k3s pod: it
lives in an **LXC instance on incus-server1** (`incus1`), the Incus server of
the homelab (see the [incus-poc](https://github.com/stephane-klein/incus-poc)
repo). This isolates CI builds from the k3s cluster while sharing incus-server1
RAM/disk — only the **CPU is capped** so builds never starve the other services
of that host.

## Layout

- `instance.yaml.j2` — declarative Incus instance (template, secrets injected at
  render time). Rendered to the gitignored `instance.yaml`.
- `build-images/` — source of the custom **`forgejo-runner`** Fedora LXC image
  (podman + netbird + cloud-init), built with distrobuilder and published to the
  Scaleway S3 simplestreams remote `sklein`. Adapted from
  `stephane-klein/incus-poc/build-images` (LXC-only variant, image renamed).
- `scripts/` — mise tasks entry points.

## Architecture

- **Host**: `forgejo-runner1` LXC instance on `incus1` (incus-server1), image
  `forgejo-runner`, profile `default`, `security.nesting: "true"`.
- **Node pinning**: none (CPU `limits.cpu: "4"` caps the runner so other
  services of incus-server1 keep theirs).
- **Netbird**: the instance joins the `incus` Netbird group
  (`netbird/setup-keys/incus-auto-group`), which already has bidirectional
  access to the homelab servers. The `sklein.internal` DNS zone is distributed
  to the `incus` group so the runner resolves `forgejo.sklein.internal`
  (CNAME → nuc-i7-gen11). *Requires one `tofu apply` of `netbird-dns.tf`.*
- **TLS**: Forgejo serves a cert from the private `homelab-ca`. The instance
  trusts it (`/etc/pki/ca-trust/source/anchors/homelab-ca.crt`, written by
  cloud-init from `certs/ca/ca.crt`).
- **Jobs**: forgejo-runner runs as the dedicated system user `runner` with
  **podman** (rootless, docker-compatible socket via `podman.socket`) and starts
  through a `forgejo-runner.service` systemd unit.

## Prerequisites

- The Incus remote `incus1` configured on this workstation (see
  `incus-poc/incus-in-coreos-server/README.md`) and the `sklein` simplestreams
  remote pointing at the Scaleway S3 bucket `incus-images`.
- Gopass entries:
  - `netbird/setup-keys/incus-auto-group` — Netbird setup key (group `incus`)
  - `homelab/forgejo/actions/runner-secret` / `runner-uuid` — generated
    automatically on first `provision` via Forgejo's **offline registration**
    (no UI step needed)
  - `homelab/incus-images/SCW_ACCESS_KEY` / `SCW_SECRET_KEY` — only to publish
    the image (build-images)
- The `homelab-ca` trust anchor (`certs/ca/ca.crt`) present locally (`mise run
  setup-secret`).

## Deploy (first time)

1. **Build and publish the image** (once, from this repo):

   ```sh
   $ mise run //apps/forgejo/runner:build-image     # distrobuilder, LXC variant
   $ mise run //apps/forgejo/runner:upload-image    # publish to sklein (S3)
   ```

2. **Apply `netbird-dns.tf`** (once) so the `incus` group receives the
   `sklein.internal` zone:

   ```sh
   $ tofu apply
   ```

3. **Create the runner instance**:

   ```sh
   $ mise run //apps/forgejo/runner:apply    # render + ensure-image + incus-apply incus1:
   ```

4. **Provision the runner inside the instance** (offline registration, binary,
   podman socket, systemd):

   ```sh
   $ mise run //apps/forgejo/runner:provision
   ```

   On first run it generates the 40-hex `runner-secret`, registers the runner
   offline with Forgejo (`forgejo-cli actions register`, kubectl exec) and
   stores the returned `runner-uuid` — both persisted in Gopass. Subsequent
   runs reuse them (idempotent).

5. Verify in Forgejo: **Admin → Actions → Runners** shows `forgejo-runner1`
   (labels `ubuntu-latest`). Then push a workflow to a repo to trigger a job.

## Operations

```sh
$ mise run //apps/forgejo/runner:apply     # idempotent, reconcile the instance
$ mise run //apps/forgejo/runner:provision # re-provision runner inside the instance
$ mise run //apps/forgejo/runner:logs      # tail forgejo-runner logs
$ mise run //apps/forgejo/runner:ssh       # shell into the instance (user fedora)
$ mise run //apps/forgejo/runner:delete    # delete the instance (destructive)
```

## Building a job image (build/push to the Forgejo registry)

A workflow that builds and pushes a container image to the Forgejo container
registry (`forgejo.sklein.internal/stephane-klein/<image>`) needs credentials.
Store the registry token as a Forgejo **Actions secret** (repo/org level) and
log in inside the workflow:

```yaml
- name: Login to registry
  env:
    TOKEN: ${{ secrets.REGISTRY_TOKEN }}
  run: echo "$TOKEN" | podman login forgejo.sklein.internal -u stephane-klein --password-stdin
```

The token is created with `mise run //apps/forgejo:container-registry-token`
(stored in Gopass at `homelab/forgejo/container-registry-token`).

## Destroy

```sh
$ mise run //apps/forgejo/runner:delete
```

Deletes the `forgejo-runner1` instance from incus1. The `forgejo-runner` image,
the Netbird peer and the Forgejo registration are left in place (remove them
explicitly if needed).
