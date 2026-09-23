#!/usr/bin/env bash
# Analyst journey harness — run as a persona token against tomjpd2.
set -euo pipefail

usage() {
  echo "Usage: LAB_TOKEN=<token> $0 --case <plt-f|prj-full|...> [--config lab/config.yaml]" >&2
  echo "Optional: JF_URL=https://your.jfrog.io (else parsed from jf config for server tomjpd2)" >&2
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
  JF_URL=$(jf config show --server-id "$SID" 2>/dev/null | awk -F': ' '/^URL:/{print $2; exit}' || true)
fi
[[ -n "${JF_URL:-}" ]] || { echo "Set JF_URL or configure jf server-id tomjpd2" >&2; exit 1; }
JF_URL="${JF_URL%/}"

OUT_DIR="harness/out/${CASE}-$(date +%s)"
mkdir -p "$OUT_DIR"
SUMMARY="${OUT_DIR}/summary.ndjson"
: > "$SUMMARY"

log_step() {
  local step=$1 code=$2 detail=$3
  jq -nc --arg step "$step" --argjson code "$code" --arg detail "$detail" \
    '{step:$step,http_code:$code,detail:$detail}' >> "$SUMMARY"
  printf "[%s] HTTP %s — %s\n" "$step" "$code" "$detail"
}

http_call() {
  local method=$1 path=$2
  shift 2
  local body_file="/tmp/jf-body-$$.json"
  local code
  code=$(curl -sS -o "$body_file" -w "%{http_code}" \
    -X "$method" \
    -H "Authorization: Bearer ${LAB_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@" \
    "${JF_URL}${path}")
  echo "$code" > "/tmp/jf-code-$$.txt"
  cat "$body_file"
}

npm_name="lodash"
npm_type="npm"
npm_ver="4.17.21"
mvn_name="commons-text"
mvn_type="maven"

impact_search() {
  local label=$1 name=$2 type=$3 version=${4:-}
  local qs="/xray/api/v2/search/impactedResources?limit=10&name=$(printf %s "$name" | jq -sRr @uri)&type=$(printf %s "$type" | jq -sRr @uri)"
  [[ -n "$version" ]] && qs="${qs}&version=$(printf %s "$version" | jq -sRr @uri)"
  local body code
  body=$(http_call GET "$qs")
  code=$(cat /tmp/jf-code-$$.txt)
  echo "$body" > "${OUT_DIR}/impact-${label}.json"
  log_step "impact_search_${label}" "$code" "name=${name} type=${type}"
}

impact_search "npm" "$npm_name" "$npm_type" "$npm_ver"
impact_search "maven" "$mvn_name" "$mvn_type" ""
impact_search "docker" "$npm_name" "$npm_type" "$npm_ver"

first_path=$(jq -r '.result[]? | select(.type=="Artifact") | .path' "${OUT_DIR}/impact-npm.json" 2>/dev/null | head -1)
if [[ -n "$first_path" && "$first_path" != "null" ]]; then
  repo=$(jq -r --arg p "$first_path" '.result[]? | select(.path==$p) | .repo' "${OUT_DIR}/impact-npm.json" | head -1)
  full_path="default/${repo}/${first_path}"
  payload=$(jq -nc --arg p "$full_path" '{paths:[$p]}')
  body=$(http_call POST /xray/api/v1/summary/artifact -d "$payload")
  code=$(cat /tmp/jf-code-$$.txt)
  echo "$body" > "${OUT_DIR}/xray-summary.json"
  log_step "xray_summary_flagged" "$code" "$full_path"

  body=$(http_call GET "/artifactory/api/storage/${repo}/${first_path}")
  code=$(cat /tmp/jf-code-$$.txt)
  echo "$body" > "${OUT_DIR}/artifact-storage.json"
  log_step "artifact_properties" "$code" "${repo}/${first_path}"
else
  log_step "xray_summary_flagged" 0 "skipped — no artifact in impact search results"
  log_step "artifact_properties" 0 "skipped"
fi

BUILD_NAME="isplt-lab-npm-flagged"
BUILD_NUMBER="${LAB_BUILD_NUMBER:-1}"
PROJECT_QS=""
if [[ "$CASE" == prj-* ]]; then
  pk="isplt-${CASE}"
  BUILD_NAME="${pk}-npm-flagged"
  PROJECT_QS="?project=${pk}"
fi

body=$(http_call GET "/artifactory/api/build/${BUILD_NAME}/${BUILD_NUMBER}${PROJECT_QS}")
code=$(cat /tmp/jf-code-$$.txt)
echo "$body" > "${OUT_DIR}/build-info.json"
log_step "build_info" "$code" "${BUILD_NAME}/${BUILD_NUMBER}${PROJECT_QS}"

vcs=$(echo "$body" | jq -r '.buildInfo.vcs[0].url // .buildInfo.vcs.url // empty' 2>/dev/null || true)
if [[ -n "$vcs" && "$vcs" != "null" ]]; then
  log_step "build_vcs_github" 200 "vcs.url present: ${vcs}"
else
  log_step "build_vcs_github" 404 "no vcs.url in build info (publish with build-collect-env)"
fi

echo "Results: ${OUT_DIR}"
jq -s '.' "$SUMMARY" > "${OUT_DIR}/summary.json"
cat "${OUT_DIR}/summary.json"
