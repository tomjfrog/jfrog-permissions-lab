#!/usr/bin/env bash
# Analyst journey harness — run as a persona token against tomjpd2.
# Follows the chain an analyst clicks through:
#   Impact Search hit → Xray summary → artifact build.name/build.number → Build Info → CI run URL
set -euo pipefail

usage() {
  echo "Usage: LAB_TOKEN=<token> $0 --case <plt-f|prj-full|...> [--config lab/config.yaml]" >&2
  echo "Optional: JF_URL=https://your.jfrog.io (else read from jf config for server tomjpd2)" >&2
  exit 1
}

CASE=""
CONFIG="lab/config.yaml"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) CASE="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

[[ -n "$CASE" ]] || usage
[[ -f "$CONFIG" ]] || { echo "Missing config: $CONFIG (copy from lab/config.example.yaml)" >&2; exit 1; }
[[ -n "${LAB_TOKEN:-}" ]] || { echo "Set LAB_TOKEN to the persona access token" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

SID="tomjpd2"
if [[ -z "${JF_URL:-}" ]] && command -v jf >/dev/null; then
  JF_URL=$(jf config show "$SID" 2>/dev/null | awk -F':[[:space:]]+' '/^JFrog Platform URL:/{print $2; exit}' || true)
fi
[[ -n "${JF_URL:-}" ]] || { echo "Set JF_URL or configure jf server-id tomjpd2" >&2; exit 1; }
JF_URL="${JF_URL%/}"

GITHUB_REPO="tomjfrog/jfrog-permissions-lab"
NPM_NAME="semver";        NPM_VER="7.6.3"
MVN_NAME="commons-lang3"; MVN_NS="org.apache.commons"; MVN_VER="3.14.0"

PROJECT_KEY=""
PROJECT_QS=""
LAB_REPO_RE='^isplt-(npm|maven|docker)-local$'
LAB_BUILD_RE='^isplt-lab-'
if [[ "$CASE" == prj-* ]]; then
  PROJECT_KEY="isplt-${CASE}"
  PROJECT_QS="?project=${PROJECT_KEY}"
  LAB_REPO_RE="^${PROJECT_KEY}-"
  LAB_BUILD_RE="^${PROJECT_KEY}-"
fi

OUT_DIR="harness/out/${CASE}-$(date +%s)"
mkdir -p "$OUT_DIR"
SUMMARY="${OUT_DIR}/summary.ndjson"
: > "$SUMMARY"
BODY="${OUT_DIR}/.body"
CODE=0

log_step() {
  local step=$1 code=$2 detail=$3
  jq -nc --arg step "$step" --argjson code "$code" --arg detail "$detail" \
    '{step:$step,http_code:$code,detail:$detail}' >> "$SUMMARY"
  printf "[%s] HTTP %s — %s\n" "$step" "$code" "$detail"
}

# Sets CODE; response body is left in $BODY.
http_call() {
  local method=$1 path=$2
  shift 2
  CODE=$(curl -sS -o "$BODY" -w "%{http_code}" -X "$method" \
    -H "Authorization: Bearer ${LAB_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@" "${JF_URL}${path}") || CODE=0
}

uri() { printf %s "$1" | jq -sRr @uri; }

impact_search() {
  local label=$1 qs=$2
  http_call GET "/xray/api/v2/search/impactedResources?limit=100&${qs}"
  cp "$BODY" "${OUT_DIR}/impact-${label}.json"
  SEARCH_CODE=$CODE
}

# Impact Search returns docker hits with `name` = full manifest path, other artifacts with `path` + `name`.
artifact_rows() {
  jq -r '.result[]? | select(.type=="Artifact")
    | [.repo, (if (.name|startswith("/")) then .name else ((.path // "/") + .name) end),
       (.artifact_pkg_version.type // "")] | @tsv' "$1" 2>/dev/null \
    | sed -E 's#//+#/#g'
}

check_ci_run() {
  local label=$1 bi=$2
  local run_url
  run_url=$(jq -r '.buildInfo.url // empty' "$bi")
  if [[ -z "$run_url" ]]; then
    run_url=$(jq -r '.buildInfo.properties // {} |
      if .["buildInfo.env.GITHUB_RUN_ID"] then
        "\(.["buildInfo.env.GITHUB_SERVER_URL"])/\(.["buildInfo.env.GITHUB_REPOSITORY"])/actions/runs/\(.["buildInfo.env.GITHUB_RUN_ID"])"
      else empty end' "$bi")
  fi
  if [[ "$run_url" == *"github.com/${GITHUB_REPO}/actions/runs/"* ]]; then
    log_step "ci_run_url:${label}" 200 "$run_url"
  else
    log_step "ci_run_url:${label}" 404 "no GitHub Actions run URL in build info (got '${run_url}')"
  fi
}

fetch_build() {
  local label=$1 name=$2 number=$3
  http_call GET "/artifactory/api/build/$(uri "$name")/$(uri "$number")${PROJECT_QS}"
  local bi="${OUT_DIR}/build-${label}.json"
  cp "$BODY" "$bi"
  log_step "build_info:${label}" "$CODE" "${name}/${number}${PROJECT_QS}"
  if [[ "$CODE" == 200 ]]; then
    check_ci_run "$label" "$bi"
  else
    log_step "ci_run_url:${label}" 0 "skipped — build info not readable"
  fi
}

follow_artifact() {
  local label=$1 repo=$2 rel=$3
  local payload
  payload=$(jq -nc --arg p "default/${repo}${rel}" '{paths:[$p]}')
  http_call POST /xray/api/v1/summary/artifact -d "$payload"
  cp "$BODY" "${OUT_DIR}/xray-summary-${label}.json"
  local err
  err=$(jq -r '[.errors[]?.error] | join("; ")' "$BODY" 2>/dev/null || true)
  log_step "xray_summary:${label}" "$CODE" "${repo}${rel}${err:+ — $err}"

  http_call GET "/artifactory/api/storage/${repo}${rel}?properties"
  cp "$BODY" "${OUT_DIR}/props-${label}.json"
  local bname bnum
  bname=$(jq -r '.properties["build.name"][0] // empty' "$BODY" 2>/dev/null || true)
  bnum=$(jq -r '.properties["build.number"][0] // empty' "$BODY" 2>/dev/null || true)
  log_step "artifact_properties:${label}" "$CODE" "build.name=${bname:-?} build.number=${bnum:-?}"

  if [[ -n "$bname" && -n "$bnum" ]]; then
    fetch_build "$label" "$bname" "$bnum"
  else
    log_step "build_info:${label}" 0 "skipped — no build.name/build.number readable on artifact"
    log_step "ci_run_url:${label}" 0 "skipped"
  fi
}

# Build result field names are not yet confirmed on tomjpd2; try the likely candidates and keep the raw record.
follow_build_hits() {
  local ecosystem=$1 file=$2
  local n=0
  while IFS=$'\t' read -r bname bnum; do
    [[ -n "$bname" && "$bname" =~ $LAB_BUILD_RE ]] || continue
    n=$((n + 1))
    fetch_build "${ecosystem}-build${n}" "$bname" "$bnum"
  done < <(jq -r '.result[]? | select(.type=="Build")
      | [(.build_name // .name // ""), (.build_number // .version // .number // "")] | @tsv' "$file" 2>/dev/null)
  jq -c '[.result[]? | select(.type=="Build")]' "$file" > "${OUT_DIR}/build-hits-${ecosystem}.json" 2>/dev/null || true
  BUILD_HITS=$n
}

# The docker image is found through the npm dependency baked into it, so docker reuses the npm search
# and only follows docker-typed hits; npm and maven follow everything else.
run_ecosystem() {
  local ecosystem=$1 file=$2
  local lab=0 out_of_scope_done=0
  while IFS=$'\t' read -r repo rel ptype; do
    [[ -n "$repo" ]] || continue
    if [[ "$ecosystem" == docker ]]; then
      [[ "$ptype" == docker ]] || continue
    else
      [[ "$ptype" != docker ]] || continue
    fi
    if [[ "$repo" =~ $LAB_REPO_RE ]]; then
      lab=$((lab + 1))
      follow_artifact "${ecosystem}-art${lab}" "$repo" "$rel"
    elif [[ $out_of_scope_done == 0 ]]; then
      out_of_scope_done=1
      http_call GET "/artifactory/api/storage/${repo}${rel}"
      log_step "out_of_scope_artifact:${ecosystem}" "$CODE" "${repo}${rel} (deny expected)"
    fi
  done < <(artifact_rows "$file")
  BUILD_HITS=0
  [[ "$ecosystem" == docker ]] || follow_build_hits "$ecosystem" "$file"
  log_step "impact_hits:${ecosystem}" "$SEARCH_CODE" "lab_artifacts=${lab} lab_builds=${BUILD_HITS}"
}

impact_search npm "name=$(uri "$NPM_NAME")&type=npm&version=$(uri "$NPM_VER")"
log_step impact_search_npm "$SEARCH_CODE" "name=${NPM_NAME} type=npm version=${NPM_VER}"
NPM_SEARCH_CODE=$SEARCH_CODE
run_ecosystem npm "${OUT_DIR}/impact-npm.json"

impact_search maven "name=$(uri "$MVN_NAME")&type=maven&namespace=$(uri "$MVN_NS")&version=$(uri "$MVN_VER")"
log_step impact_search_maven "$SEARCH_CODE" "name=${MVN_NAME} type=maven version=${MVN_VER}"
run_ecosystem maven "${OUT_DIR}/impact-maven.json"

SEARCH_CODE=$NPM_SEARCH_CODE
log_step impact_search_docker "$SEARCH_CODE" "reuses npm search; following docker hits"
run_ecosystem docker "${OUT_DIR}/impact-npm.json"

rm -f "$BODY"
jq -s '.' "$SUMMARY" > "${OUT_DIR}/summary.json"
echo "Results: ${OUT_DIR}"
