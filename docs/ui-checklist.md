# UI checklist — analyst journey

Perform each step logged in as the **persona user** for the case under test (not admin). Record pass/fail and screenshots in `docs/results-template.md`.

## Platform case (example `lab-plt-f`)

1. Log in to tomjpd2 Platform UI as `lab-plt-f`.
2. **Xray → Scans List → Impact Search**
3. Search package: `semver`, type `npm` (or use config red-flag coordinates).
4. Confirm flagged npm artifact appears; open the resource link.
5. Confirm Xray scan / component view loads (not 403 / empty).
6. Repeat Impact Search for Maven `org.apache.commons:commons-lang3` / `maven` and npm `semver` for Docker-track image.
7. From the artifact, read the `build.name` / `build.number` properties (or open a Build-type search result directly).
8. Open that build under **Artifactory → Builds**.
9. Confirm Build Info shows the **Build URL** (`https://github.com/tomjfrog/jfrog-permissions-lab/actions/runs/<id>`) and `GITHUB_*` environment values.
10. Follow the Build URL to the GitHub Actions run that published the build.
11. Deny check: open the `npm-remote-cache` semver hit from step 3 — expect no access for every non-admin persona.

## Project case (example `lab-prj-full`)

1. Log in as `lab-prj-full`.
2. Switch context to project `isplt-prj-full` if the UI requires it.
3. Repeat steps 2–10 using artifacts/builds under that project’s repos only.
4. Optional isolation check: as `lab-prj-full`, attempt to open an artifact in `isplt-prj-developer` repos — expect deny.

## Expected customer failure signatures

| Case | Impact Search | Scan / artifact | Build Info |
|------|---------------|-----------------|------------|
| plt-a | May work | Often fails (no repo Read) | Fails |
| plt-d | Works | Works | Fails (no build Read) |
| prj_noreports | Fails / denied | — | — |
| prj_nobuild | Works | Works | Fails |
