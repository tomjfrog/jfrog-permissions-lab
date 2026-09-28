# Apply lab on tomjpd2

All commands use **`--server-id tomjpd2`**. Run from repo root with admin credentials in `jf config`.

Order matters: Xray can only index builds that exist, and personas must be verified clean before any result is trusted.

## 1. Bootstrap config

```bash
cp lab/config.example.yaml lab/config.yaml
bash scripts/generate-platform-permissions.sh
bash scripts/generate-user-specs.sh
```

## 2. Create platform repositories

**Required before the GitHub publish workflow** — otherwise `jf npm-config` fails with `The repository 'isplt-npm' does not exist`.

```bash
bash scripts/provision-platform-repos.sh
```

| Key | Type |
|-----|------|
| `isplt-npm-local`, `isplt-maven-local`, `isplt-docker-local` | Local (Xray index on) |
| `isplt-npm`, `isplt-maven`, `isplt-docker` | Virtual (local + existing remotes `npm-remote`, `mavencentral-remote`) |

Override remotes: `LAB_NPM_REMOTE=… LAB_MAVEN_REMOTE=… bash scripts/provision-platform-repos.sh`

## 3. Create persona users

Each `permissions/users/*.json` has a `.user` object that is the request body for [Create User](https://docs.jfrog.com/administration/reference/createuser.md). It carries the Xray role flags directly (`reports_manager`, `watch_manager`, `policy_manager`, Artifactory 7.128.0+) — no UI step for Manage Reports.

```bash
for f in permissions/users/lab-*.json; do
  U=$(jq -r .user.username "$f")
  PW="<from vault for ${U}>"
  jq --arg pw "$PW" '.user + {password: $pw}' "$f" \
    | jq -c . | jf api --server-id tomjpd2 -X POST /access/api/v2/users \
        -H "Content-Type: application/json" --input=-
done
```

Store passwords in a team vault; do not commit.

### 3a. Strip auto-join groups (required)

On tomjpd2 the `readers` group is **auto-join**, and the built-in **`Anything`** permission grants `readers` Read on every repository and every build. A persona left in `readers` passes the whole journey regardless of its case, which invalidates the matrix.

```bash
for f in permissions/users/lab-*.json; do
  U=$(jq -r .user.username "$f")
  G=$(jf api --server-id tomjpd2 "/access/api/v2/users/${U}" | jq -c '.groups // []')
  if [[ "$G" != "[]" ]]; then
    echo "removing ${U} from ${G}"
    jq -nc --argjson g "$G" '{add: [], remove: $g}' \
      | jf api --server-id tomjpd2 -X PATCH "/access/api/v2/users/${U}/groups" \
          -H "Content-Type: application/json" --input=-
  fi
done
```

Re-run the loop; every persona must report no groups before continuing.

## 4. Apply Permissions V2 (platform track)

Build targets use the `artifactory-build-info` repository key with build-name patterns inside it (`isplt-lab-*/**`).

```bash
for c in B C D E F G H I; do
  jf api --server-id tomjpd2 -X POST /access/api/v2/permissions \
    -H "Content-Type: application/json" --input "permissions/platform/case-${c}.json"
done
```

Case **A** has no resource grants — skip POST.

**Case G:** Manage Xray Metadata is the V2 action `SCAN` (confirmed on tomjpd2 by saving it in the UI and reading it back), so `case-G.json` grants `READ`, `ANNOTATE`, `SCAN` with no UI step.

## 5. Create JFrog Projects (project track)

```bash
for PK in isplt-prj-full isplt-prj-noreports isplt-prj-nobuild isplt-prj-noartifact isplt-prj-developer; do
  jf api --server-id tomjpd2 -X POST /access/api/v1/projects \
    -H "Content-Type: application/json" --input "permissions/project/${PK}/project.json"
  if [[ -f "permissions/project/${PK}/role-security-analyst.json" ]]; then
    jf api --server-id tomjpd2 -X POST "/access/api/v1/projects/${PK}/roles" \
      -H "Content-Type: application/json" --input "permissions/project/${PK}/role-security-analyst.json"
  fi
  U=$(jq -r .name "permissions/project/${PK}/member.json")
  jf api --server-id tomjpd2 -X PUT "/access/api/v1/projects/${PK}/users/${U}" \
    -H "Content-Type: application/json" --input "permissions/project/${PK}/member.json"
done
```

Project role actions on tomjpd2: Read Artifacts = `READ_REPOSITORY`, Read Builds = `READ_BUILD`, Manage Reports = `REPORTS_SECURITY`. List valid actions with `jf api --server-id tomjpd2 "/access/api/v1/projects/${PK}/roles"`.

Then create the project repos:

```bash
bash scripts/provision-project-repos.sh
```

If the `${PK}-npm` virtual is rejected, share `npm-remote` with the lab projects first (Administration → Repositories → `npm-remote` → Share with projects).

## 6. Publish artifacts

Configure GitHub `vars.JF_URL` and OIDC secrets ([`github-setup.md`](github-setup.md)), then run **Publish lab artifacts**:

1. `track=platform` — shared haystack repos.
2. `track=projects` — npm flagged build per project.

## 7. Index builds in Xray

Repo indexing alone is not enough: the npm package and Maven jar carry no dependency graph of their own, so `semver` and `commons-lang3` only surface through the **build** dependencies, and Impact Search returns Build results only for indexed builds.

```bash
bash scripts/index-lab-builds.sh             # platform builds
bash scripts/index-lab-builds.sh --projects  # plus project builds
```

Then re-run the publish workflow once so the new build numbers are scanned.

## 8. Verify coverage as admin

Before creating persona tokens, confirm Impact Search returns a lab hit per ecosystem:

```bash
for q in "name=semver&type=npm&version=7.6.3" "name=org.apache.commons:commons-lang3&type=maven&version=3.14.0"; do
  jf api --server-id tomjpd2 "/xray/api/v2/search/impactedResources?limit=100&${q}" \
    | jq -c '[.result[] | {type, repo, name}]'
done
```

Expect the docker-flagged manifest plus Build results for `isplt-lab-npm-flagged`, `isplt-lab-docker-flagged`, and `isplt-lab-maven-flagged`. The `npm-remote-cache` hit is intentional — the harness uses it as a deny check.

## 9. Issue persona tokens

```bash
jf access-token-create lab-plt-f --server-id tomjpd2 --description "lab harness" --expiry 864000
```

Save tokens under `lab/tokens/` (gitignored).

## 10. Run harness

```bash
export LAB_TOKEN="$(cat lab/tokens/lab-plt-f.token)"
./harness/journey.sh --case plt-f --config lab/config.yaml
```

The harness reads build name and number from the artifact's `build.name` / `build.number` properties, so no build number needs to be passed. Record output in `docs/results-template.md`.
