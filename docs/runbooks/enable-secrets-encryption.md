# Enable at-rest encryption of k3s Secrets

## Goal / When to use

Enable `secrets-encryption` on an **existing** k3s cluster started without this
flag. Secrets are then encrypted at rest in the datastore (AES-CBC, key stored
in the datastore bootstrap data and in `cred/encryption-config.json`).

Official procedure available since k3s v1.33.10+ (March 2026) — see the
[k3s secrets-encrypt documentation](https://docs.k3s.io/cli/secrets-encrypt).
This cluster runs v1.36.1.

## Prerequisites

- SSH access to the control-plane node (`nuc-i7-gen11`)
- Restart window: the procedure restarts the k3s server (API briefly suspended,
  workloads unaffected)

## Steps

> Problem at any step? → [Troubleshooting](#troubleshooting)
> Cluster unusable or secrets unreadable? → [Rollback](#rollback) (restores the step-1 backup)

1. **From the workstation** — take a control-plane backup (safety net, mandatory
   before touching the datastore):

   ```sh
   $ mise run backup-k3s-control-plane
   ```

2. Connect to the control-plane node — **all following commands run on the
   node** (`nuc-i7-gen11`):

   ```sh
   $ ssh stephane@nuc-i7-gen11.homelab.stephane-klein.info
   ```

3. Verify encryption is disabled:
   ```sh
   stephane@nuc-i7-gen11:~$ sudo k3s secrets-encrypt status
   # → Encryption Status: Disabled, no configuration file found
   ```

4. Enable encryption:
   ```sh
   stephane@nuc-i7-gen11:~$ sudo k3s secrets-encrypt enable
   ```

5. Add the flag to `/etc/rancher/k3s/config.yaml` then restart:
   ```yaml
   secrets-encryption: true
   ```
   ```sh
   stephane@nuc-i7-gen11:~$ sudo systemctl restart k3s
   ```

6. Verify activation is in progress (`start` stage):
   ```sh
   stephane@nuc-i7-gen11:~$ sudo k3s secrets-encrypt status
   # → Encryption Status: Disabled / Current Rotation Stage: start
   #   Server Encryption Hashes: All hashes match
   ```

7. Rotate keys to enable encryption for new Secrets:
   ```sh
   stephane@nuc-i7-gen11:~$ sudo k3s secrets-encrypt rotate-keys
   ```

   > **This command blocks until re-encryption of all existing Secrets
   > finishes.** K3s re-encrypts ~5 secrets/second, so it can take a while on
   > clusters with many Secrets — this is normal. Track progress with
   > `sudo k3s secrets-encrypt status` (`reencrypt_active` → `reencrypt_finished`)
   > or `journalctl -u k3s -f`.

8. Restart the server:
   ```sh
   stephane@nuc-i7-gen11:~$ sudo systemctl restart k3s
   ```

9. Verify encryption is active and re-encryption finished:
   ```sh
   stephane@nuc-i7-gen11:~$ sudo k3s secrets-encrypt status
   Encryption Status: Enabled
   Current Rotation Stage: reencrypt_finished
   Server Encryption Hashes: All hashes match

   Active  Key Type  Name
   ------  --------  ----
   *      AES-CBC   aescbckey-2026-08-19T16:40:43+02:00
   ```

## Verification

On the control-plane node (same SSH session):

```sh
# Secrets are encrypted in the datastore
sudo strings /var/lib/rancher/k3s/server/db/state.db | grep -c 'k8s:enc:aescbc'
# → > 0
```

From the workstation:

```sh
# The API still decrypts (normal behaviour)
kubectl get secrets -A
kubectl get pods -A
```

Take a fresh backup from the workstation: `mise run backup-k3s-control-plane` (the
`cred/encryption-config.json` is now part of the tarball).

## Troubleshooting

1. **k3s fails to restart, or the API is slow to come back** — check the service
   and logs, and re-check the encryption status:
   ```sh
   sudo systemctl status k3s
   journalctl -u k3s -n 100
   sudo k3s secrets-encrypt status
   ```
   The re-encryption runs at ~5 secrets/second; on this small cluster it
   finishes quickly. Wait for the API and re-check `kubectl get nodes`.

2. **`secrets-encrypt status` reports an unexpected stage** (stuck in `start`,
   `rotate`, or `reencrypt_active`) — each stage requires a server restart
   before the next. Restart and re-check:
   ```sh
   sudo systemctl restart k3s
   sudo k3s secrets-encrypt status
   ```

3. **`newer than datastore` fatal error at startup** — a bootstrap file on disk
   is newer than the datastore. Remove the offending file and let k3s recreate
   it from the datastore:
   ```sh
   sudo rm /var/lib/rancher/k3s/server/cred/encryption-config.json
   sudo systemctl restart k3s
   ```

4. **Agent node reports `NotReady` after the restarts** — agents reconnect
   automatically once the server is back. Verify with `kubectl get nodes`; if a
   node stays down, restart its agent service:
   ```sh
   ssh stephane@nuc-i3-gen5.homelab.stephane-klein.info
   sudo systemctl restart k3s-agent
   ```

5. **Secrets unreadable after a bad restore** — restore the step-1 backup
   tarball together with the cluster token (see the
   [Rollback](#rollback) section or README → Backup and restore).

## Rollback

**First try to disable encryption** (on the control-plane node, same SSH
session):

```sh
sudo k3s secrets-encrypt disable
sudo systemctl restart k3s
sudo k3s secrets-encrypt reencrypt --force --skip
sudo systemctl restart k3s
```

**If the cluster is unusable or secrets are unreadable** — restore the backup
taken in step 1. It contains the pre-encryption `state.db` + `cred/` + `tls/`
tarball, restored with the cluster token:

```sh
# From the workstation
mise run restore-k3s-control-plane
```

> **Note:** the keys live in the datastore (`state.db`). The critical backup is
> the `state.db` + `cred/` + `tls/` tarball (see README → Backup and restore).
> The cluster token (`K3S_TOKEN`) is required for restore.

## Execution history

| Date | Executed by | Result |
|------|-------------|--------|
| 2026-08-19 | Stéphane | Success — status `Enabled`, `reencrypt_finished` |
