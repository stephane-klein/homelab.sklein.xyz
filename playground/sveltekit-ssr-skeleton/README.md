# sveltekit-ssr-skeleton — playground

Test deployment of [sveltekit-ssr-skeleton](https://github.com/stephane-klein/sveltekit-ssr-skeleton) application with Authelia OpenID Connect authentication.

## Deploy

```sh
$ helmfile -f helmfile.yaml.gotmpl apply
```

Create an OIDC user:

```bash
$ curl -k -X POST \
    -H "Authorization: Bearer ${SVELTEKIT_SSR_SKELETON_ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"email":"contact@stephane-klein.info","display_name":"Stéphane Klein","oidc_issuer":"https://auth.sklein.internal/","oidc_subject":"stephane"}' \
    https://sveltekit-ssr-skeleton-myapp-test.sklein.internal/api/v1/admin/users | jq
```

## URLs

- App: https://sveltekit-ssr-skeleton-myapp-test.sklein.internal
- OIDC issuer: https://auth.sklein.internal




## Destroy

```sh
$ helmfile -f helmfile.yaml.gotmpl destroy
```
