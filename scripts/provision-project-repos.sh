#!/usr/bin/env bash
# Create per-project npm repos for the project track (idempotent — skips existing).
# Run after the isplt-prj-* projects exist and before Publish lab artifacts (track=projects).
set -euo pipefail
SID="${JFROG_SERVER_ID:-tomjpd2}"
export JFROG_CLI_USER_AGENT="${JFROG_CLI_USER_AGENT:-jfrog-permissions-lab-provision/1.0}"
NPM_REMOTE="${LAB_NPM_REMOTE:-npm-remote}"
PROJECTS=(isplt-prj-full isplt-prj-noreports isplt-prj-nobuild isplt-prj-noartifact isplt-prj-developer)

repo_exists() {
  jf api --server-id "$SID" "/artifactory/api/repositories/$1" >/dev/null 2>&1
}

create_repo() {
  local key=$1 body=$2
  if repo_exists "$key"; then
    echo "skip (exists): $key"
    return 0
  fi
  echo "create: $key"
  jf api --server-id "$SID" "/artifactory/api/repositories/${key}" \
    -X PUT -H "Content-Type: application/json" -d "$body"
}

for pk in "${PROJECTS[@]}"; do
  create_repo "${pk}-npm-local" "{
    \"key\": \"${pk}-npm-local\",
    \"rclass\": \"local\",
    \"packageType\": \"npm\",
    \"projectKey\": \"${pk}\",
    \"description\": \"Impact Search permissions lab — ${pk} npm local\",
    \"xrayIndex\": true
  }"

  # The virtual can only include ${NPM_REMOTE} if that remote is shared with the project.
  create_repo "${pk}-npm" "{
    \"key\": \"${pk}-npm\",
    \"rclass\": \"virtual\",
    \"packageType\": \"npm\",
    \"projectKey\": \"${pk}\",
    \"description\": \"Impact Search permissions lab — ${pk} npm virtual\",
    \"repositories\": [\"${pk}-npm-local\", \"${NPM_REMOTE}\"],
    \"defaultDeploymentRepo\": \"${pk}-npm-local\"
  }"
done

echo "Project repos ready. Run Publish lab artifacts (track=projects), then scripts/index-lab-builds.sh."
