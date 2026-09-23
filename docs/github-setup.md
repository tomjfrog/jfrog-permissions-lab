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

### Secrets (OIDC — recommended)

| Name | Purpose |
|------|---------|
| `OIDC_PROVIDER_NAME` | OIDC provider name configured in JFrog for GitHub |
| `OIDC_AUDIENCE` | OIDC audience configured for that provider |

```bash
gh secret set OIDC_PROVIDER_NAME --repo tomjfrog/jfrog-permissions-lab
gh secret set OIDC_AUDIENCE --repo tomjfrog/jfrog-permissions-lab
```

### Alternative: access token

If OIDC is not configured, change [`.github/workflows/publish-lab-artifacts.yml`](../.github/workflows/publish-lab-artifacts.yml) to use `JF_ACCESS_TOKEN` per the `setup-jfrog-cli` skill and set:

```bash
gh secret set JF_ACCESS_TOKEN --repo tomjfrog/jfrog-permissions-lab
```

The publish identity must be able to deploy to lab repos on **tomjpd2** (admin or CI service user).

## After secrets are set

1. Apply JFrog resources: [`apply-tomjpd2.md`](apply-tomjpd2.md)
2. **Actions → Publish lab artifacts → Run workflow** (`track=platform`, then `track=projects`)
