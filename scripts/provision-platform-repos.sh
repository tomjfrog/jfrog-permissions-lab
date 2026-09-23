#!/usr/bin/env bash
# Create platform-track lab repos on tomjpd2 (idempotent — skips existing).
set -euo pipefail
SID="${JFROG_SERVER_ID:-tomjpd2}"
export JFROG_CLI_USER_AGENT="${JFROG_CLI_USER_AGENT:-jfrog-permissions-lab-provision/1.0}"

repo_exists() {
  local key=$1
  jf api --server-id "$SID" "/artifactory/api/repositories/${key}" -X HEAD 2>/dev/null | grep -q '200' && return 0
  local code
  code=$(jf api --server-id "$SID" "/artifactory/api/repositories/${key}" -X HEAD 2>&1 | grep -oE 'Http Status: [0-9]+' | awk '{print $3}')
  [[ "$code" == "200" ]]
}

create_repo() {
  local key=$1
  local body=$2
  if repo_exists "$key"; then
    echo "skip (exists): $key"
    return 0
  fi
  echo "create: $key"
  jf api --server-id "$SID" "/artifactory/api/repositories/${key}" \
    -X PUT -H "Content-Type: application/json" -d "$body"
}

# Remotes already on tomjpd2 — adjust if your instance uses different keys
NPM_REMOTE="${LAB_NPM_REMOTE:-npm-remote}"
MAVEN_REMOTE="${LAB_MAVEN_REMOTE:-mavencentral-remote}"

create_repo isplt-npm-local '{
  "key": "isplt-npm-local",
  "rclass": "local",
  "packageType": "npm",
  "description": "Impact Search permissions lab — npm local",
  "xrayIndex": true
}'

create_repo isplt-maven-local '{
  "key": "isplt-maven-local",
  "rclass": "local",
  "packageType": "maven",
  "repoLayoutRef": "maven-2-default",
  "description": "Impact Search permissions lab — maven local",
  "xrayIndex": true
}'

create_repo isplt-docker-local '{
  "key": "isplt-docker-local",
  "rclass": "local",
  "packageType": "docker",
  "dockerApiVersion": "V2",
  "description": "Impact Search permissions lab — docker local",
  "xrayIndex": true
}'

create_repo isplt-npm "{
  \"key\": \"isplt-npm\",
  \"rclass\": \"virtual\",
  \"packageType\": \"npm\",
  \"description\": \"Impact Search permissions lab — npm virtual\",
  \"repositories\": [\"isplt-npm-local\", \"${NPM_REMOTE}\"],
  \"defaultDeploymentRepo\": \"isplt-npm-local\"
}"

create_repo isplt-maven "{
  \"key\": \"isplt-maven\",
  \"rclass\": \"virtual\",
  \"packageType\": \"maven\",
  \"repoLayoutRef\": \"maven-2-default\",
  \"description\": \"Impact Search permissions lab — maven virtual\",
  \"repositories\": [\"isplt-maven-local\", \"${MAVEN_REMOTE}\"],
  \"defaultDeploymentRepo\": \"isplt-maven-local\"
}"

create_repo isplt-docker '{
  "key": "isplt-docker",
  "rclass": "virtual",
  "packageType": "docker",
  "dockerApiVersion": "V2",
  "description": "Impact Search permissions lab — docker virtual",
  "repositories": ["isplt-docker-local"],
  "defaultDeploymentRepo": "isplt-docker-local"
}'

echo "Platform repos ready. Re-run Publish lab artifacts (track=platform)."
