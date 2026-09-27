#!/usr/bin/env bash
# Generate platform permission JSON for cases B–I from templates (run from repo root).
set -euo pipefail

REPOS=(isplt-npm-local isplt-maven-local isplt-docker-local)
# Build permissions target the build-info repo; build names are matched as "<name>/**" paths inside it.
BUILD_REPO='artifactory-build-info'
LAB_BUILDS='isplt-lab-*/**'

artifact_targets() {
  local u=$1 actions=$2
  shift 2
  local -a parts=()
  for r in "$@"; do
    parts+=("\"$r\": {\"include_patterns\": [\"**\"], \"exclude_patterns\": []}")
  done
  local targets
  targets=$(IFS=,; echo "${parts[*]}")
  cat <<EOF
    "artifact": {
      "targets": { $targets },
      "actions": { "users": { "$u": $actions }, "groups": {} }
    }
EOF
}

build_targets() {
  local u=$1 actions=$2 include=$3 exclude=${4:-}
  local exclude_json='[]'
  [[ -n "$exclude" ]] && exclude_json="[\"$exclude\"]"
  cat <<EOF
    "build": {
      "targets": {
        "$BUILD_REPO": { "include_patterns": ["$include"], "exclude_patterns": $exclude_json }
      },
      "actions": { "users": { "$u": $actions }, "groups": {} }
    }
EOF
}

write_case() {
  local case=$1
  shift
  local file="permissions/platform/case-${case}.json"
  {
    echo '{'
    echo "  \"name\": \"isplt-plt-${case}\","
    echo '  "resources": {'
    local IFS=$',\n'
    echo "$*"
    echo '  }'
    echo '}'
  } > "$file"
  jq empty "$file"
  echo "wrote $file"
}

mkdir -p permissions/platform

R='["READ"]'
RA='["READ", "ANNOTATE"]'

write_case B "$(artifact_targets lab-plt-b "$R" "${REPOS[@]}")"
write_case C "$(build_targets lab-plt-c "$R" "$LAB_BUILDS")"
write_case D "$(artifact_targets lab-plt-d "$R" "${REPOS[@]}")"
write_case E "$(build_targets lab-plt-e "$R" "$LAB_BUILDS")"
write_case F "$(artifact_targets lab-plt-f "$R" "${REPOS[@]}"),$(build_targets lab-plt-f "$R" "$LAB_BUILDS")"
# G: Manage Xray Metadata is added in the UI after POST (see docs/apply-tomjpd2.md); Watches/Policies are user flags.
write_case G "$(artifact_targets lab-plt-g "$RA" "${REPOS[@]}"),$(build_targets lab-plt-g "$RA" "$LAB_BUILDS")"
write_case H "$(artifact_targets lab-plt-h "$R" isplt-npm-local),$(build_targets lab-plt-h "$R" "$LAB_BUILDS")"
write_case I "$(artifact_targets lab-plt-i "$R" "${REPOS[@]}"),$(build_targets lab-plt-i "$R" '**' "$LAB_BUILDS")"

# Case A: no Access permission target (reports_manager user flag only) — marker file
echo '{"name":"isplt-plt-A","note":"No artifact/build grants; reports_manager user flag only"}' \
  > permissions/platform/case-A.json

echo "Done. Xray role flags (reports_manager etc.) live in permissions/users/*.json."
