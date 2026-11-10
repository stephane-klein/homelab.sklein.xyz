# The Artifact

[The Artifact](https://github.com/andidev30/the-artifact) hosts the HTML pages
coding agents publish over MCP. An agent calls `publish_artifact`, the app
stores the page and returns a link, and the pages stay private until their
owner shares them.

- App: `https://artifact.stephane-klein.info`
- Page content: `https://artifact-content.stephane-klein.info`
- Both served by `traefik-public` (IPv6 `2001:861:8b91:6620::1000`), TLS from
  the `letsencrypt-public` ClusterIssuer, AAAA records from external-dns.
- No Authelia in front: the app manages its own accounts, agents and tokens,
  and pages shared with "anyone with the link" must open for people outside
  the homelab.

The second host name is `CONTENT_ORIGIN`. It serves page files and nothing
else, so published HTML never shares an origin with the session cookie. The
upstream project recommends a separate registrable domain; here it is a
subdomain of the same zone, which still separates the hosts and the cookies.

## Layout

- [`helmfile.yaml`](./helmfile.yaml) — three releases, applied in order:
  1. `the-artifact-cluster` — CloudNativePG PostgreSQL 18 (chart `cnpg/cluster`
     0.7.0), 10 Gi on `nuc-i3-gen5`, nightly S3 backup.
  2. `rustfs` — RustFS 1.0.4 in standalone mode (chart `rustfs/rustfs`): one
     pod, one 20 Gi `local-path` PVC, Service `rustfs-svc:9000`.
  3. `the-artifact` — the application (OCI chart 1.2.0).
- [`values-cnpg.yaml`](./values-cnpg.yaml) — database and its backup.
- [`values-rustfs.yaml`](./values-rustfs.yaml) — object storage.
- [`values.yaml`](./values.yaml) — application, ingress, SMTP, thumbnails.
- [`scripts/`](./scripts/) — deploy, destroy, diff, status, seccomp install, make-admin.
- [`../../config/seccomp/the-artifact-chromium.json`](../../config/seccomp/the-artifact-chromium.json)
  — the seccomp profile the thumbnails need, copied from the upstream
  `deploy/seccomp-chromium.json` (itself Docker's default profile plus
  `clone`, `unshare` and `setns`).

Three values files, not one: the three charts use `ingress`, `resources`,
`nodeSelector` and `secret` with different meanings, so a shared file would
silently configure the wrong things.

## Dependencies

Shared infrastructure deployed elsewhere:

- CloudNativePG operator (`mise run deploy-cnpg`).
- cert-manager with the `letsencrypt-public` ClusterIssuer.
- `traefik-public` with CrowdSec in front.
- external-dns (creates the AAAA records for both hosts).
- Scaleway Object Storage bucket `homelab-cnpg-backups` (database backups, under
  the `/the-artifact` prefix).

The nodes need the Chromium seccomp profile, see below.

## Secrets

Created by `scripts/deploy.sh` with `kubectl create secret`, from Gopass:

| Secret | Keys | Gopass entry |
|:---|:---|:---|
| `rustfs-credentials` | `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY` | `homelab/the-artifact/s3/access-key`, `homelab/the-artifact/s3/secret-key` |
| `the-artifact-settings` | `ENCRYPTION_KEY`, `SETUP_CODE`, `SMTP_PASS` | `homelab/the-artifact/encryption-key`, `homelab/the-artifact/setup-code`, `homelab/the-artifact/smtp-password` |
| `the-artifact-cluster-backup-s3-creds` | `ACCESS_KEY_ID`, `ACCESS_SECRET_KEY` | `homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY`, `homelab/scaleway/CNPG_BACKUPS_SECRET_KEY` |

Create them once:

```sh
$ openssl rand -base64 32 | gopass insert -m homelab/the-artifact/encryption-key
$ gopass insert homelab/the-artifact/setup-code          # at least 12 characters
$ gopass cp toggl.sklein.internal/fastmail-smtp homelab/the-artifact/smtp-password
$ gopass insert homelab/the-artifact/s3/access-key
$ gopass insert homelab/the-artifact/s3/secret-key
```

`ENCRYPTION_KEY` must outlive the database: it encrypts the keys the server
keeps in `server_secrets`, so a restored backup without it does not start.
Keep it in Gopass, not only in the cluster.

`SETUP_CODE` is what lets the first account claim a fresh install. Once that
account exists the code does nothing.

## Deploy

```sh
$ mise run //apps/the-artifact:install-seccomp
$ mise run //apps/the-artifact:deploy
```

`deploy.sh` creates the namespace and the three secrets, installs the seccomp
profile on both nodes, runs `helmfile apply`, and waits for the application
pod.

## Status

```sh
$ mise run //apps/the-artifact:status
```

The command is read-only. It prints the three releases and their versions, the
pods, the volumes, the ingress, the TLS certificate and its expiry, the AAAA
records of both hosts compared to `::1000`, `kubectl cnpg status` with the five
latest backups, the application's `/readyz` answer (which covers PostgreSQL and
the RustFS bucket together), the effective seccomp profile, the last log lines
mentioning Chromium, and the two public endpoints.

It exits `0` when `https://artifact.stephane-klein.info/healthz` answers `200`,
and `1` otherwise. The other sections are informational: a database or bucket
outage shows in the `/readyz` line without changing the exit code.

## First account

The first account becomes the instance admin, and it needs the setup code:

```sh
$ gopass show -o homelab/the-artifact/setup-code
```

Then, in **Server admin**:

- set the instance name;
- set the sign-up policy to **invited only** (the default is "anyone" until it
  is saved);
- add a passkey or an authenticator app to the admin account.

Connect an agent once the app answers:

```sh
$ claude mcp add --transport http --scope user the-artifact https://artifact.stephane-klein.info/mcp
```

## Thumbnails and the seccomp profile

Gallery thumbnails, `inspect_artifact` and PDF export are rendered by Chromium
inside the pod. Chromium keeps its sandbox on, and that sandbox creates user,
PID and network namespaces, which means `clone` with namespace flags,
`unshare` and `setns`.

The container runtime's default seccomp profile refuses those calls to a
container without `CAP_SYS_ADMIN`, so Chromium cannot start its sandbox. The
profile in `config/seccomp/the-artifact-chromium.json` adds exactly those three
calls to the default profile; `mount`, `bpf`, `ptrace` and the rest stay
denied.

Kubernetes cannot ship a seccomp profile in a ConfigMap: the kubelet reads a
`Localhost` profile from its own disk. The chart therefore asks for
`profiles/the-artifact-chromium.json`, resolved under the kubelet root
directory, `/var/lib/kubelet` on k3s:

```sh
$ mise run //apps/the-artifact:install-seccomp
```

The task copies the file to `/var/lib/kubelet/seccomp/profiles/` on
`nuc-i7-gen11` and `nuc-i3-gen5` and checks the SHA-256 on both. Run it again
after re-provisioning a node: `/var` survives CoreOS updates, not a reinstall.
Without the file the pod never starts, and `kubectl describe pod` says it could
not load the seccomp profile.

To go without thumbnails instead, set `thumbnails.enabled: false` in
`values.yaml`; the pod then runs under `RuntimeDefault`, the gallery shows
sketches, and `inspect_artifact` and PDF export report that they are
unavailable.

## Storage

Page content lives in the RustFS bucket `artifact-content`. RustFS runs in
standalone mode: one pod on `nuc-i3-gen5`, one 20 Gi `local-path` volume, no
replication.

**Nothing copies that volume off the node.** If the disk or the node is lost,
every published page is lost; the PostgreSQL side stays restorable from its S3
backups, but the content does not. This is a deliberate first step. To change
it later, add a CronJob that mirrors the bucket to a Scaleway bucket, on the
model of [`apps/forgejo/backup/`](../forgejo/backup/), using `rclone` or `mc`
against `http://rustfs-svc:9000`.

The console (port 9001) is not exposed. Reach it with a port-forward when
needed:

```sh
$ kubectl -n the-artifact port-forward svc/rustfs-svc 9001:9001
```

## Database backups

CloudNativePG takes a nightly backup at 02:30 to
`s3://homelab-cnpg-backups/the-artifact/`, with 30 days of retention.

```sh
$ kubectl cnpg backup the-artifact-cluster -n the-artifact
$ kubectl get backups.postgresql.cnpg.io -n the-artifact
```

## Upgrading

Read the upstream changelog first, then change the chart version in
`helmfile.yaml` and apply again:

```sh
$ mise run //apps/the-artifact:deploy
```

The app migrates the database when the new pod starts, and the chart replaces
the pod rather than rolling it, so two pods never migrate at once.

## Troubleshooting

Pod stuck in `CreateContainerConfigError`:

```sh
$ kubectl -n the-artifact describe pod -l app.kubernetes.io/component=app | grep -i seccomp
```

That means the profile is missing on the node: run the `install-seccomp` task.

A page with no thumbnail, or `inspect_artifact` answering that it is not
available:

```sh
$ kubectl -n the-artifact logs deploy/the-artifact -c app | grep -i -e chromium -e chrome
```

Losing the only admin: `mise run //apps/the-artifact:make-admin -- someone@example.com`
prints a password link.

## Destroy

> Destructive: removing the CNPG cluster deletes the database and its volumes.
> The RustFS data PVC is annotated `helm.sh/resource-policy: keep`, so the
> published pages stay on disk until `pvc/rustfs-data` is deleted by hand.

```sh
$ mise run //apps/the-artifact:destroy
```
