# Operations log

Chronological log of one-off operational actions on the homelab that are not
visible in git history (they happen on servers/cluster). Append-only: add a row,
never edit past rows.

| Date | Action | Context / Why | Result | Ref |
|------|--------|---------------------|----------|-----|
| 2026-08-19 | Enabled k3s secrets encryption at rest | Secrets were stored plaintext in the SQLite datastore | Success — status `Enabled`, `reencrypt_finished` | runbooks/enable-secrets-encryption.md |
