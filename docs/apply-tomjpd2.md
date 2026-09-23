# Apply lab on tomjpd2

All commands use **`--server-id tomjpd2`**. Run from repo root with admin credentials in `jf config`.

## 1. Bootstrap config

```bash
cp lab/config.example.yaml lab/config.yaml
bash scripts/generate-platform-permissions.sh
bash scripts/generate-user-specs.sh
```

## 2. Create platform repositories

Create local repos `isplt-npm-local`, `isplt-maven-local`, `isplt-docker-local` and virtual repos `isplt-npm`, `isplt-maven`, `isplt-docker` (include locals + org remotes). Enable **Xray indexing** on the three local repos and on build info indexing for platform builds.

Example (adjust package types via REST GET template from an existing repo):

```bash
export JFROG_CLI_USER_AGENT='jfrog-permissions-lab-apply/1.0'
# jf api --server-id tomjpd2 POST /artifactory/api/repositories/npm -d @lab/repo-templates/npm-local.json
```

Repo JSON templates are not generated here — use UI or copy from an existing npm/maven/docker local repo on tomjpd2.

## 3. Create persona users

For each file in `permissions/users/lab-plt-*.json` and `lab-prj-*.json`:

```bash
USER=lab-plt-f
jf api --server-id tomjpd2 POST /access/api/v2/users/ \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${USER}\",\"email\":\"${USER}@labs.invalid\",\"password\":\"<set-secure>\",\"admin\":false}"
```

Store passwords in a team vault; do not commit.

## 4. Assign platform Xray roles (Manage Reports)

Platform personas **A, D–I** need global **Manage Reports** (Reports Manager). Assign in **Administration → User Management → Users →** select user → **Global Roles** (or equivalent) → enable **Manage Reports**.

Cases **B, C, E** omit Manage Reports per matrix.

Project-track personas receive Manage Reports via **project custom role** except `isplt-prj-noreports`.

## 5. Apply Permissions V2 (platform track)

For each `permissions/platform/case-*.json` with a `resources` object:

```bash
jf api --server-id tomjpd2 POST /access/api/v2/permissions \
  -H "Content-Type: application/json" \
  --input permissions/platform/case-F.json
```

Case **A** has no resource grants — skip POST.

## 6. Create JFrog Projects (project track)

For each directory under `permissions/project/isplt-prj-*`:

```bash
PK=isplt-prj-full
jf api --server-id tomjpd2 POST /access/api/v1/projects \
  -H "Content-Type: application/json" \
  --input "permissions/project/${PK}/project.json"
```

Create repos `${PK}-npm-local`, `${PK}-npm` (virtual), assign `projectKey`, index for Xray.

Create custom role (except Developer-only project):

```bash
jf api --server-id tomjpd2 POST "/access/api/v1/projects/${PK}/roles" \
  -H "Content-Type: application/json" \
  --input "permissions/project/${PK}/role-security-analyst.json"
```

Add member:

```bash
jf api --server-id tomjpd2 PUT "/access/api/v1/projects/${PK}/users/lab-prj-full" \
  -H "Content-Type: application/json" \
  --input "permissions/project/${PK}/member.json"
```

If `MANAGE_XRAY_REPORTS` is rejected, list valid actions:

```bash
jf api --server-id tomjpd2 "/access/api/v1/projects/${PK}/roles"
```

Match UI **Manage Reports** to the returned action name and update the role JSON.

## 7. Publish artifacts

Configure GitHub `vars.JF_URL` and OIDC secrets, then run workflow **Publish lab artifacts**:

1. `track=platform` — populates shared haystack repos.
2. `track=projects` — publishes npm flagged build per project.

Set `LAB_BUILD_NUMBER` to `${{ github.run_number }}` when running the harness.

## 8. Wait for Xray

Confirm scans completed (UI or `jf rt build-scan` logs). Impact Search requires SBOM service enabled ([Impact Search docs](https://docs.jfrog.com/security/docs/impact-search-1)).

## 9. Issue persona tokens

```bash
jf access-token-create lab-plt-f --server-id tomjpd2 --description "lab harness" --expiry 864000
```

Save tokens under `lab/tokens/` (gitignored).

## 10. Run harness

```bash
export LAB_TOKEN="$(cat lab/tokens/lab-plt-f.token)"
export LAB_BUILD_NUMBER=1
export JF_URL=https://<tomjpd2-host>
./harness/journey.sh --case plt-f --config lab/config.yaml
```

Record output in `docs/results-template.md`.
