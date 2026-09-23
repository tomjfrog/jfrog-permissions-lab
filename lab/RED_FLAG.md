# Red-flag coordinates (lab default)

These match `lab/config.example.yaml`. Change only together with apps and re-publish.

| Ecosystem | Package | Version | Impact Search `type` |
|-----------|---------|---------|----------------------|
| npm | lodash | 4.17.21 | npm |
| Maven | commons-text (org.apache.commons) | 1.9 | maven |
| Docker image SBOM | lodash (via `apps/docker-flagged`) | 4.17.21 | npm |

Selection rationale: widely indexed in Xray, pinned versions, not chosen as active incident/malware packages.
