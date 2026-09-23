# Impact Search Analyst Permissions Lab

Lab on JFrog Platform Deployment **`tomjpd2`** to find the least-privilege permissions for a Security Analyst to complete:

**Impact Search → Xray scan result → Build Info → GitHub Actions run**

Covers **platform Permissions V2** (cases A–I) and **JFrog Project** roles (one project + persona per case). Produces npm, Maven, and Docker artifacts (flagged + decoys) via GitHub Actions with Build Info.

## Naming conventions

Lab resources and personas use short prefixes so you can tell **platform-wide** setup from **project-scoped** setup at a glance:

| Prefix | Scope | Examples |
|--------|--------|----------|
| **`plt`** | **Platform** — Permissions V2 targets, global Xray roles, and personas that are *not* tied to a JFrog Project | User `lab-plt-f`, permission `isplt-plt-F`, harness `--case plt-f`, matrix cases A–I |
| **`prj`** | **Project** — JFrog Projects, project repos/build-info, project roles, and personas that belong to one project | Project `isplt-prj-full`, user `lab-prj-full`, harness `--case prj-full` |

Shared artifact repos and build names use the `isplt-` prefix (lab namespace on tomjpd2); that prefix does not mean “platform” by itself — look for **`plt`** vs **`prj`** in the segment that follows (`isplt-plt-*` vs `isplt-prj-*`, or `lab-plt-*` vs `lab-prj-*` users).

## Prerequisites

- JFrog CLI configured with `--server-id tomjpd2`
- `jq`, `bash`
- GitHub: see [`docs/github-setup.md`](docs/github-setup.md) for `JF_URL` and `OIDC_PROVIDER_NAME` on [tomjfrog/jfrog-permissions-lab](https://github.com/tomjfrog/jfrog-permissions-lab)
- Admin credentials on tomjpd2 for apply (not used by the analyst harness)

## Layout

| Path | Purpose |
|------|---------|
| [`lab/config.example.yaml`](lab/config.example.yaml) | Copy to `lab/config.yaml`; server, repos, red-flag packages, personas |
| [`harness/matrix.yaml`](harness/matrix.yaml) | Permission cases and journey steps |
| [`harness/journey.sh`](harness/journey.sh) | Run analyst API journey as a persona token |
| [`permissions/`](permissions/) | V2 permission bodies, project roles, user specs |
| [`apps/`](apps/) | Sample npm / Maven / Docker projects |
| [`docs/apply-tomjpd2.md`](docs/apply-tomjpd2.md) | Provision tomjpd2 |
| [`docs/teardown-tomjpd2.md`](docs/teardown-tomjpd2.md) | Remove lab resources |
| [`docs/ui-checklist.md`](docs/ui-checklist.md) | Manual UI parity with harness |
| [`docs/results-template.md`](docs/results-template.md) | Record outcomes per persona |

## Quick start (after apply)

1. Copy config: `cp lab/config.example.yaml lab/config.yaml` and adjust if needed.
2. **Platform repos on tomjpd2:** `bash scripts/provision-platform-repos.sh` (must run before GitHub publish).
3. Apply users, permissions, projects: follow [`docs/apply-tomjpd2.md`](docs/apply-tomjpd2.md).
4. Run GitHub Actions workflow **Publish lab artifacts** (`workflow_dispatch`).
5. Wait for Xray indexing and scans on lab repos.
6. Create persona tokens (runbook) and run:

```bash
export JFROG_CLI_USER_AGENT='jfrog-permissions-lab-harness/1.0'
export LAB_TOKEN='<persona-token>'
./harness/journey.sh --case plt-f --config lab/config.yaml
```

7. Fill [`docs/results-template.md`](docs/results-template.md); compare UI using [`docs/ui-checklist.md`](docs/ui-checklist.md).

## Red-flag packages (Impact Search needle)

Pinned coordinates in `lab/config.example.yaml` — swap only after re-scanning and updating workflows. Used for package-mode Impact Search (`name` + `type` + optional `version`).

## References

- [Impact Search](https://docs.jfrog.com/security/docs/impact-search-1)
- [Search impacted resources API](https://docs.jfrog.com/security/docs/search-resources-by-vulnerability-and-package)
- [Permissions](https://docs.jfrog.com/administration/docs/permissions)
- [Project roles](https://docs.jfrog.com/projects/docs/project-roles)
