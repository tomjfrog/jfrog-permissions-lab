# Red-flag coordinates (lab default)

These match `lab/config.example.yaml`. Change only together with apps and re-publish.

| Ecosystem | Package | Version | Impact Search `type` |
|-----------|---------|---------|----------------------|
| npm | semver | 7.6.3 | npm |
| Maven | commons-lang3 (org.apache.commons) | 3.14.0 | maven |
| Docker image SBOM | semver (via `apps/docker-flagged`) | 7.6.3 | npm |

Chosen to stay **Curation-friendly**: common utilities at pinned, non-blocked versions (replacing lodash / commons-text, which were blocked on tomjpd2).
