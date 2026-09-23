# GitHub repository setup

Repository: [tomjfrog/jfrog-permissions-lab](https://github.com/tomjfrog/jfrog-permissions-lab)

## Required for **Publish lab artifacts** workflow

### Repository variable

| Name | Example | Purpose |
|------|---------|---------|
| `JF_URL` | `https://<your-tomjpd2-host>` | JFrog Platform base URL (no trailing path) |

Set with:

```bash
gh variable set JF_URL --repo tomjfrog/jfrog-permissions-lab --body 'https://YOUR_TOMJPD2_URL'
```

### Secret (OIDC)

| Name | Purpose |
|------|---------|
| `OIDC_PROVIDER_NAME` | OIDC provider name as configured in JFrog (Administration → OIDC) |

```bash
gh secret set OIDC_PROVIDER_NAME --repo tomjfrog/jfrog-permissions-lab
```

**No `OIDC_AUDIENCE` secret is required.** The workflow omits `oidc-audience` on `jfrog/setup-jfrog-cli@v4`, so the action uses the default audience (typically the GitHub repository owner URL). That must match what you configured on the JFrog OIDC integration. If you use a custom audience in JFrog, add optional repo variable `JF_OIDC_AUDIENCE` and wire it in the workflow — most tomjfrog setups do not need this.

Workflow permissions must include `id-token: write` (already set in the workflow).

### Alternative: access token

If OIDC is not configured, set `JF_ACCESS_TOKEN` on the setup step env and remove the `with: oidc-provider-name` block per the [setup-jfrog-cli](https://docs.jfrog.com/administration/docs/openid-connect-integration) token example:

```bash
gh secret set JF_ACCESS_TOKEN --repo tomjfrog/jfrog-permissions-lab
```

The publish identity must be able to deploy to lab repos on **tomjpd2** (admin or CI service user).

## After secrets are set

1. Apply JFrog resources: [`apply-tomjpd2.md`](apply-tomjpd2.md)
2. **Actions → Publish lab artifacts → Run workflow** (`track=platform`, then `track=projects`)
