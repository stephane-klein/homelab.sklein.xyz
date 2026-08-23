# sveltekit-ssr-skeleton — playground

Test deployment of [sveltekit-ssr-skeleton](https://github.com/stephane-klein/sveltekit-ssr-skeleton) application with Authelia OpenID Connect authentication.

## Deploy

```sh
$ mise run //playground/sveltekit-ssr-skeleton:deploy
```

This creates the `sveltekit-ssr-skeleton-myapp-secrets` Secret from Gopass
(AUTHELIA_CLIENT_SECRET, MY_APP_ADMIN_TOKEN, SMTP_PASS) and applies
`helmfile.yaml`.

Create an OIDC user:

```bash
$ curl -k -X POST \
    -H "Authorization: Bearer $(gopass show -o homelab/sveltekit_ssr_skeleton/ADMIN_TOKEN)" \
    -H "Content-Type: application/json" \
    -d '{"email":"contact@stephane-klein.info","display_name":"Stéphane Klein","oidc_issuer":"https://auth.sklein.internal/","oidc_subject":"stephane"}' \
    https://sveltekit-ssr-skeleton-myapp-test.sklein.internal/api/v1/admin/users | jq
```

## Test SMTP

```sh
$ mise run //playground/sveltekit-ssr-skeleton:test-smtp
```

Sends a test email via `smtp.fastmail.com:465` using SMTP parameters from `values.yaml` (password retrieved from Gopass).

## URLs

- App: https://sveltekit-ssr-skeleton-myapp-test.sklein.internal
- OIDC issuer: https://auth.sklein.internal

## Destroy

```sh
$ helmfile -f helmfile.yaml destroy
```
