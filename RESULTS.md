# Impact Search analyst permissions — results

**JPD:** `tomjpd2` (https://tomjpd2.jfrog.io) · **Date:** 2026-09-27 · **Status:** platform track complete (API + UI); project track complete (API).

## Question

What is the least privilege a Security Analyst needs to go from an **Impact Search** result → the **package or build** it references → **Build Info** → the **CI run URL** that produced it?

## Answer (platform track)

The smallest grant that completes every hop on npm, Maven, and Docker is **case F**:

| Grant | Where it is set | Needed for |
|-------|-----------------|------------|
| **Manage Reports** | User flag `reports_manager` (Access v2 user) | Running Impact Search at all |
| **Build Read** on `artifactory-build-info`, pattern covering the build names (e.g. `isplt-lab-*/**`) | Permissions V2 `build` resource | Opening Build Info (and therefore the CI run URL) on every route |
| **Repo Read** on the repos holding the flagged artifacts | Permissions V2 `artifact` resource | Only the artifact route: opening a flagged artifact/image and reading its `build.name` / `build.number` |

Case G (F + Annotate + Manage Xray Metadata + Manage Watches + Manage Policies) produced identical results — none of those extras are required.

When Impact Search returns the **Build** itself (npm and Maven in this lab), **Manage Reports + Build Read** is sufficient (case E). Repo Read is only required when the analyst starts from an **artifact** hit (Docker here).

## Key findings

1. **The customer's failure signature is reproduced by case D** (Manage Reports + Repo Read, no Build Read). Search, Xray summary, and artifact properties all succeed; the last hop fails with:
   > The user: 'lab-plt-d' is not authorized to access build info. Read permission is needed.

   Case I (Build Read whose pattern excludes the lab builds) fails identically — the build pattern must match the build *names*.

2. **Impact Search results are not permission-filtered.** Every persona with Manage Reports received the same result set as admin (npm: 3 artifacts + 2 builds; Maven: 7 artifacts + 1 build), including remote-cache hits and builds the persona cannot open. This explains "I can see it but can't open it", and means result names are visible to anyone with Manage Reports.

3. **Missing Repo Read fails soft, not with 403.** Without Repo Read on the artifact's repo:
   - `POST /xray/api/v1/summary/artifact` → **200** with an empty `artifacts` list
   - `GET /artifactory/api/storage/<path>?properties` → **404** "No properties could be found."

   An unreadable artifact is indistinguishable from one with no build linked. Missing Build Read, by contrast, returns an explicit 403 with a clear message.

4. **Missing Manage Reports returns 403 with an empty body** on Impact Search — no hint about which permission is missing (cases B, C).

5. **Resource grants work independently of search.** Direct probes (no search) show B's Repo Read and C's Build Read are effective; only the Impact Search entry point is blocked without Manage Reports.

6. **CI run URL is always in Build Info.** Every build published by the workflow carries the Actions run URL in `buildInfo.url` plus `GITHUB_*` env vars. `buildInfo.vcs` is empty; the URL is the reliable link. Whether the analyst can open the run depends on GitHub access to `tomjfrog/jfrog-permissions-lab`, which is outside JFrog permissions.

## Platform results (cases A–I)

All personas are non-admin, have no group memberships, and ran with their own token (token subject verified before each run). Hit counts were identical for every case that could search.

Legend: ✅ 200 · ❌ 403 · ⚠️ soft deny (access refused, but returned as 200 with an empty body or 404 instead of 403) · — not reached

| Case | Grants | Impact Search | Docker: summary → props → build → CI | npm via Build hit | Maven via Build hit | Remote-cache hit | Outcome |
|------|--------|---------------|--------------------------------------|-------------------|---------------------|------------------|---------|
| A | Manage Reports | ✅ | ⚠️ → ⚠️ → — → — | ❌ | ❌ | ❌ | Search only |
| B | Repo Read | ❌ | — | — | — | — | Blocked at search |
| C | Build Read | ❌ | — | — | — | — | Blocked at search |
| D | MR + Repo Read | ✅ | ✅ → ✅ → ❌ → — | ❌ | ❌ | ❌ | **Customer bug** |
| E | MR + Build Read | ✅ | ⚠️ → ⚠️ → — → — | ✅ → ✅ | ✅ → ✅ | ❌ | Builds only |
| F | MR + Repo Read + Build Read | ✅ | ✅ → ✅ → ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ❌ | **Full journey** |
| G | F + Annotate + Scan + Watches/Policies | ✅ | ✅ → ✅ → ✅ → ✅ | ✅ → ✅ | ✅ → ✅ | ❌ | Same as F |
| H | F, Repo Read on npm local only | ✅ | ⚠️ → ⚠️ → — → — | ✅ → ✅ | ✅ → ✅ | ❌ | Docker route fails |
| I | F, Build Read excludes `isplt-lab-*/**` | ✅ | ✅ → ✅ → ❌ → — | ❌ | ❌ | ❌ | Build Info fails |

Direct probes (npm build 5 / Maven build 5 / Docker manifest properties): A ❌❌⚠️ · B ❌❌✅ · C ✅✅⚠️ · D ❌❌✅ · E ✅✅⚠️ · F ✅✅✅ · G ✅✅✅ · H ✅✅⚠️ · I ❌❌✅

Raw evidence: `harness/out/plt-{a..i}-179055*/` (`summary.json` plus each response body).

## Project track results

Each persona is a member of one project (`isplt-prj-<case>`) through a project role, with no platform grants, no Xray user flags, and no groups. Each project has an npm local + virtual and a flagged npm build (`isplt-prj-<case>-npm-flagged/8`) that records `semver:7.6.3` and the Actions run URL.

**Least-privilege project role:** Read Artifacts is not needed for the Build route. **Manage Reports (`REPORTS_SECURITY`) + Read Builds (`READ_BUILD`)** completes Impact Search → Build hit → Build Info → CI run URL — the project equivalent of platform case E. Add Read Artifacts (`READ_REPOSITORY`) for artifact hits; in this lab the project npm locals produce no artifact hits (the tarball has no dependency graph), so that hop was not exercised on the project track.

| Case | Role actions | Impact Search (`projectKey`) | Own build → CI URL | Other project's build | Remote-cache hit |
|------|--------------|------------------------------|--------------------|-----------------------|------------------|
| `prj-full` | READ_REPOSITORY, READ_BUILD, REPORTS_SECURITY | ✅ | ✅ → ✅ | ❌ | ✅ (shared remote) |
| `prj-noreports` | READ_REPOSITORY, READ_BUILD | ❌ | — | — | — |
| `prj-nobuild` | READ_REPOSITORY, REPORTS_SECURITY | ✅ | ❌ → — | ❌ | ✅ (shared remote) |
| `prj-noartifact` | READ_BUILD, REPORTS_SECURITY | ✅ | ✅ → ✅ | ❌ | ❌ |
| `prj-developer` | built-in Developer | ❌ | — | — | — |

Raw evidence: `harness/out/prj-*-17905584*/`.

### Project track findings

7. **Project Manage Reports only works when the search names the project.** `GET /xray/api/v2/search/impactedResources` must include `projectKey=<project>`. Without it the search is platform-level and a project-only analyst gets **403** even with `REPORTS_SECURITY`. `project=`, `project_key=`, and an `X-JFrog-Project` header all still return 403. Expected UI equivalent (not yet verified): the analyst must run Impact Search with the project selected, not from the platform view.

8. **Project-scoped search is still not permission-filtered.** With `projectKey`, a project analyst receives the same global result list as admin: platform builds, all five lab projects' builds, the Docker manifests, and remote-cache hits. Names outside the project are visible; opening them is not.

9. **Build isolation holds.** Every persona got 403 "not authorized to access build info" on another project's build, including `prj-full`. Missing `READ_BUILD` fails the same way on the persona's own build (`prj-nobuild`), matching platform case D.

10. **The built-in Developer role cannot search.** It lacks Manage Reports, so the journey stops at Impact Search.

11. **Shared remotes leak artifact reads into project roles.** `npm-remote` is shared with all projects (`autoShare=true`), so `READ_REPOSITORY` lets project analysts open `npm-remote-cache` hits; `mavencentral-remote-cache` behaved the same way. This is expected sharing behaviour rather than a cross-project leak, but it widens what a project analyst can open beyond the project's own repos.

## How the lab is set up

- **Haystack:** `isplt-{npm,maven,docker}-local` (Xray-indexed) behind virtuals; flagged and clean apps for each ecosystem, published by GitHub Actions (`Publish lab artifacts`) with build-info, `build-collect-env`, and artifact `build.name`/`build.number` properties.
- **Needles:** npm `semver@7.6.3` (also inside the `isplt-docker-flagged` image), Maven `org.apache.commons:commons-lang3:3.14.0`.
- **Build indexing:** all `isplt-lab-*` builds added to Xray indexing. Without it, Impact Search returns no Build results and the npm/Maven needles are invisible (the published npm tarball and jar carry no dependency graph Xray can read).
- **Personas:** one user per case (`lab-plt-a` … `lab-plt-i`), Xray role flags set at creation, removed from the auto-join `readers` group.
- **Permissions:** one Permissions V2 target per case (`isplt-plt-B` … `I`), bound only to that persona. Case A has no target.
- **Harness:** `harness/journey.sh` follows the analyst's path — search → artifact → properties → build → CI URL, and search → Build hit → build → CI URL — and attempts to open an out-of-lab hit as a deny check.

## Platform facts confirmed on tomjpd2

| Fact | Detail |
|------|--------|
| Manage Reports (platform) | User flag `reports_manager` (also `watch_manager`, `policy_manager`); Artifactory 7.128.0+ |
| Manage Reports (project role) | Action `REPORTS_SECURITY` |
| Manage Xray Metadata (Permissions V2) | Action `SCAN` |
| Build permission target | Repository key `artifactory-build-info`, build names as path patterns (`<name>/**`) |
| Maven Impact Search name | `groupId:artifactId` (`org.apache.commons:commons-lang3`); bare artifactId matches nothing |
| Impact Search Build hit fields | Build name in `name`, build number in `version` |
| Default group trap | `readers` is auto-join and the built-in `Anything` permission grants it Read on all repos and builds — personas must be removed from it or every case passes |
| `jf api` stdin body | `--input=-` works; `--input -` fails with "Wrong number of arguments" |

## Validity checks

- **Admin coverage gate:** Impact Search returns a lab needle for every ecosystem before any persona is tested.
- **Deny baseline:** `lab-plt-b` with no grants and no Manage Reports received 403 on every search — nothing outside the lab grants access once `readers` is removed.
- **Read-back:** all eight permission targets matched the repo JSON exactly.
- **Identity:** each run's token subject was checked against its case. One early baseline run that accidentally used the admin token was discarded.

## Open items

- [x] **UI parity (next-steps step 12):** click-through as `lab-plt-a`, `-d`, `-f`, `-h` done manually in the UI.
- [ ] **Research `lab-plt-h` in the UI:** the case H click-through (Repo Read on npm local only) was harder to complete than the others. Work out what the UI does differently from the API result above (Docker route soft-denied, npm/Maven Build hits open).
- [x] **Project track (steps 13–17):** see "Project track results". The harness now adds `projectKey` to Impact Search for `prj-*` cases and opens one other project's build as an isolation check.
- [ ] **Project artifact route:** not exercised, because project npm locals produce no artifact hits. To test `READ_REPOSITORY` on the artifact route, add a project Docker image (like `isplt-docker-flagged`) to one project.
- [ ] **Project UI parity:** confirm the project-context Impact Search in the UI behaves as finding 7 describes.
- [x] **Harness:** an Xray summary 200 with empty `artifacts` is logged with `denied: true` and a "soft deny" detail. Every step in `summary.json` now has a `denied` field (HTTP ≥ 400 unless overridden).
- [x] **Harness guard:** `journey.sh` decodes `LAB_TOKEN`'s subject and refuses to run when it doesn't match the case (`plt-<x>[-suffix]` → `lab-plt-<x>`, `prj-<name>` → `lab-prj-<name>`). `admin-*` cases refuse persona tokens; other case names are rejected.
- [ ] **Credentials:** revoke the persona tokens and remove `lab/tokens/` when testing is complete.
