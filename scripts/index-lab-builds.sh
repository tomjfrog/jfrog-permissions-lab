#!/usr/bin/env bash
# Add lab builds to Xray indexing so Impact Search can return Build results and see build dependencies.
# Builds must already be published at least once (Xray only lists builds it can see in Artifactory).
set -euo pipefail
SID="${JFROG_SERVER_ID:-tomjpd2}"
export JFROG_CLI_USER_AGENT="${JFROG_CLI_USER_AGENT:-jfrog-permissions-lab-provision/1.0}"

PLATFORM_BUILDS=(
  isplt-lab-npm-flagged isplt-lab-npm-clean
  isplt-lab-maven-flagged isplt-lab-maven-clean
  isplt-lab-docker-flagged isplt-lab-docker-clean
)
PROJECTS=(isplt-prj-full isplt-prj-noreports isplt-prj-nobuild isplt-prj-noartifact isplt-prj-developer)

index_builds() {
  local qs=$1
  shift
  local cur new
  cur=$(jf api --server-id "$SID" "/xray/api/v1/binMgr/default/builds${qs}")
  new=$(echo "$cur" | jq --args '
    reduce $ARGS.positional[] as $b (.;
      .indexed_builds = ((.indexed_builds // []) + [$b] | unique)
      | .non_indexed_builds = ((.non_indexed_builds // []) - [$b]))' "$@")
  jf api --server-id "$SID" -X PUT "/xray/api/v1/binMgr/default/builds${qs}" \
    -H "Content-Type: application/json" -d "$new"
  echo "indexed${qs:+ ($qs)}: $*"
}

index_builds "" "${PLATFORM_BUILDS[@]}"

if [[ "${1:-}" == "--projects" ]]; then
  for pk in "${PROJECTS[@]}"; do
    index_builds "?projectKey=${pk}" "${pk}-npm-flagged"
  done
fi
