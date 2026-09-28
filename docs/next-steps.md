# Next steps — tomjpd2 lab

State as of 2026-09-27: platform repos and six `isplt-lab-*` builds (numbers 2–3) exist; no personas, permissions, or projects; lab builds are not Xray-indexed, so Impact Search only finds the Docker image. Repo fixtures and harness are fixed but uncommitted.

Each step lists **Intent** (what it does), **Proves** (what a pass tells you), and **How**. Commands detail lives in [`apply-tomjpd2.md`](apply-tomjpd2.md); step numbers there are cited as "runbook §N".

---

## Phase 1 — Make the data searchable

- [x] **1. Commit and push the fixture fixes**
  - **Intent:** `workflow_dispatch` runs the workflow from the default branch, so the npm build-info fix must be on `main`.
  - **Proves:** nothing.
  - **How:** review `git diff`, commit, `git push`.

- [x] **2. Index the platform lab builds in Xray**
  - **Intent:** Impact Search only returns Build results, and only sees `semver` in the npm build and `commons-lang3` in the Maven build, for indexed builds. Today all six are in `non_indexed_builds`.
  - **Proves:** nothing yet (setup).
  - **How:** `bash scripts/index-lab-builds.sh`
    Check: `jf api --server-id tomjpd2 /xray/api/v1/binMgr/default/builds | jq '.indexed_builds | map(select(startswith("isplt-lab-")))'` lists all six.

- [x] **3. Re-run Publish lab artifacts (platform)**
  - **Intent:** produce a new build number where the npm build records `semver` as a dependency, and have Xray scan the now-indexed builds.
  - **Proves:** the npm dependency-capture fix works (npm-flagged build shows `semver:7.6.3` in `modules[].dependencies`).
  - **How:** `gh workflow run "Publish lab artifacts" -f track=platform --repo tomjfrog/jfrog-permissions-lab`, then
    `jf api --server-id tomjpd2 /artifactory/api/build/isplt-lab-npm-flagged/<N> | jq '[.buildInfo.modules[].dependencies[].id]'`

- [x] **4. Admin coverage check (gate)**
  - **Intent:** confirm the haystack actually contains a needle for every ecosystem before any persona is tested. If admin can't find it, a persona failing proves nothing.
  - **Proves:** fixtures are valid: Impact Search returns the docker-flagged manifest plus Build results for the npm, Maven, and Docker lab builds, and each build carries the Actions run URL.
  - **How:** runbook §8, then the admin smoke run:
    ```bash
    export LAB_TOKEN=$(jq -r '.servers[]|select(.serverId=="tomjpd2")|.accessToken' ~/.jfrog/jfrog-cli.conf.v6)
    ./harness/journey.sh --case admin-smoke --config lab/config.yaml
    ```
    Expect `lab_builds>=1` for npm and maven and `lab_artifacts>=1` for docker, with every `ci_run_url` step at 200. Open `harness/out/admin-smoke-*/build-hits-*.json` and confirm the build name/number field names the harness guesses (`build_name`/`name`, `build_number`/`version`); fix `follow_build_hits` if they differ.

## Phase 2 — Platform track personas

- [x] **5. Create the 9 platform persona users**
  - **Intent:** one identity per matrix case, with Xray role flags (`reports_manager`, etc.) set at creation.
  - **Proves:** nothing (setup).
  - **How:** runbook §3 loop over `permissions/users/lab-plt-*.json`. Passwords go to your vault.

- [x] **6. Strip auto-join groups and verify**
  - **Intent:** remove personas from `readers`, which the built-in `Anything` permission grants Read on every repo and build.
  - **Proves:** personas start from zero access; without this every case passes like F.
  - **How:** runbook §3a; re-run until every persona reports `[]`:
    `for u in lab-plt-{a..i}; do echo "$u $(jf api --server-id tomjpd2 /access/api/v2/users/$u | jq -c .groups)"; done`

- [x] **7. Deny-baseline control run (before any permissions)**
  - **Intent:** run the harness as a persona with no grants and no Xray roles.
  - **Proves:** the harness reports denials correctly and nothing outside the lab grants access (such as another permission or anonymous access). Every step should be 403/skipped.
  - **How:** runbook §9 token for `lab-plt-b`, then `./harness/journey.sh --case plt-b-baseline`.

- [x] **8. Apply Permissions V2 for cases B–I**
  - **Intent:** create the resource grants per case.
  - **Proves:** the JSON is accepted by the Access API (target keys and actions are valid).
  - **How:** runbook §4. Read each back and compare:
    `jf api --server-id tomjpd2 /access/api/v2/permissions/isplt-plt-F | jq .resources`

- [x] **9. Case G extras**
  - **Intent:** add Manage Xray Metadata (the V2 action name wasn't confirmed from docs or the JPD).
  - **Proves:** the real action string, so `generate-platform-permissions.sh` can be made fully code-driven.
  - **How:** UI → Permissions → `isplt-plt-G` → add Manage Xray Metadata on repos and builds; read back per runbook §4; put the string in the generator's `RA` actions.

- [x] **10. Issue persona tokens**
  - **Intent:** credentials for the harness, one per persona.
  - **Proves:** nothing.
  - **How:** `for u in lab-plt-{a..i}; do jf access-token-create $u --server-id tomjpd2 --description "lab harness" --expiry 864000 --format json | jq -r .access_token > lab/tokens/$u.token; done` (check that one token file is non-empty before looping over all nine)

- [x] **11. Run the harness for cases A–I**
  - **Intent:** measure each hop of the journey per permission combination.
  - **Proves:** which permission each hop needs; F passing everything is the candidate least privilege.
  - **How:**
    ```bash
    for c in a b c d e f g h i; do
      LAB_TOKEN=$(cat lab/tokens/lab-plt-$c.token) ./harness/journey.sh --case plt-$c --config lab/config.yaml
    done
    ```
    Expected signatures (hypotheses to confirm or refute):

    | Case | Impact Search | Artifact / scan | Build info | CI run URL | What it proves |
    |------|---------------|-----------------|------------|------------|----------------|
    | A | 200 | denied | via Build hit: denied | — | Manage Reports alone can search but not open results |
    | B | denied | — | — | — | Repo Read without Manage Reports can't start the journey |
    | C | denied | — | — | — | Build Read alone can't start it either |
    | D | 200 | 200 | denied | — | **Customer bug signature:** the last hop needs Build Read |
    | E | 200 | denied | 200 via Build hit | 200 | Build Read works without repo Read, but only through Build results |
    | F | 200 | 200 | 200 | 200 | Candidate least privilege |
    | G | same as F | | | | Extras add nothing needed for the journey |
    | H | 200 | npm only; docker/maven denied | 200 | 200 | Repo Read must cover every ecosystem the analyst investigates |
    | I | 200 | 200 | denied | — | Build Read must match the build *name* pattern |

    Every non-admin case should also show `out_of_scope_artifact` denied.

- [x] **12. UI parity for key cases (A, D, F, H)** — done manually; case H flagged for further research (see `RESULTS.md` open items)
  - **Intent:** repeat the click-through in the Platform UI as the persona.
  - **Proves:** the UI behaves like the API. The customer experienced this through the UI, which can use different endpoints; any mismatch is itself a finding.
  - **How:** [`ui-checklist.md`](ui-checklist.md), with screenshots in `results-template.md`.

## Phase 3 — Project track

- [ ] **13. Create projects, roles, members, and project repos**
  - **Intent:** one isolated project per project case.
  - **Proves:** the role JSON is accepted (confirms `REPORTS_SECURITY` etc.).
  - **How:** runbook §5 (users from step 5 must include `lab-prj-*`, stripped per step 6), then `bash scripts/provision-project-repos.sh`. If the virtual repo is rejected, share `npm-remote` with the lab projects and re-run.

- [ ] **14. Publish and index project builds**
  - **Intent:** put flagged npm builds into each `<project>-build-info` and make them searchable.
  - **Proves:** nothing yet (setup).
  - **How:** `gh workflow run "Publish lab artifacts" -f track=projects --repo tomjfrog/jfrog-permissions-lab`, then `bash scripts/index-lab-builds.sh --projects`, then publish once more so indexed builds get scanned.

- [ ] **15. Admin coverage check for projects (gate)**
  - **Intent:** same as step 4, per project.
  - **Proves:** each project has a findable build that links to its run.
  - **How:** runbook §8 query; expect Build results named `isplt-prj-*-npm-flagged`.

- [ ] **16. Run the harness for project cases**
  - **Intent:** measure the project-role equivalents.
  - **Proves:** the least-privilege project role, and that platform-level grants aren't needed for project-scoped builds.
  - **How:** tokens as in step 10 for `lab-prj-*`, then `--case prj-full`, `prj-noreports`, `prj-nobuild`, `prj-noartifact`, `prj-developer`. Expected: `prj-full` passes all; `noreports` fails search; `nobuild` fails build info; `noartifact` fails artifact hops; `developer` records whether it passes without Manage Reports.

- [ ] **17. Cross-project isolation check**
  - **Intent:** as `lab-prj-full`, try to open `isplt-prj-developer` artifacts and builds.
  - **Proves:** project roles don't bleed across projects (Impact Search results and opens stay scoped).
  - **How:** UI checklist project step 4, or `curl` the other project's build with `?project=isplt-prj-developer` using the `lab-prj-full` token; expect a denial.

## Phase 4 — Conclude

- [ ] **18. Record results and name the least-privilege sets**
  - **Intent:** turn the harness output into the answer.
  - **Proves:** the deliverable: the smallest platform grant and project role that complete Impact Search → artifact/build → Build Info → CI run on all three ecosystems.
  - **How:** fill [`results-template.md`](results-template.md) from `harness/out/*/summary.json`; note any hypothesis in step 11 that didn't hold.

- [ ] **19. Clean up credentials**
  - **Intent:** revoke lab tokens and remove local copies.
  - **Proves:** nothing.
  - **How:** revoke per [`teardown-tomjpd2.md`](teardown-tomjpd2.md) §6, then `rm -rf lab/tokens harness/out`. Leave everything else in place until the results are reviewed.
