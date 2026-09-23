#!/usr/bin/env bash
# Generate platform permission JSON for cases B–I from templates (run from repo root).
set -euo pipefail

REPOS=(isplt-npm-local isplt-maven-local isplt-docker-local)
BUILD_PATTERN='isplt-lab**/**'

artifact_targets_all() {
  local u=$1
  local -a actions=()
  for r in "${REPOS[@]}"; do
    actions+=("\"$r\": {\"include_patterns\": [\"**\"], \"exclude_patterns\": []}")
  done
  local targets
  targets=$(IFS=,; echo "${actions[*]}")
  cat <<EOF
    "artifact": {
      "targets": { $targets },
      "actions": { "users": { "$u": ["READ"] }, "groups": {} }
    }
EOF
}

artifact_targets_npm_only() {
  local u=$1
  cat <<EOF
    "artifact": {
      "targets": {
        "isplt-npm-local": { "include_patterns": ["**"], "exclude_patterns": [] }
      },
      "actions": { "users": { "$u": ["READ"] }, "groups": {} }
    }
EOF
}

build_read() {
  local u=$1
  local exclude=${2:-}
  if [[ -n "$exclude" ]]; then
    cat <<EOF
    "build": {
      "targets": {
        "$BUILD_PATTERN": {
          "include_patterns": ["**"],
          "exclude_patterns": ["$exclude"]
        }
      },
      "actions": { "users": { "$u": ["READ"] }, "groups": {} }
    }
EOF
  else
    cat <<EOF
    "build": {
      "targets": {
        "$BUILD_PATTERN": { "include_patterns": ["**"], "exclude_patterns": [] }
      },
      "actions": { "users": { "$u": ["READ"] }, "groups": {} }
    }
EOF
  fi
}

write_case() {
  local case=$1 user=$2
  shift 2
  local file="permissions/platform/case-${case}.json"
  {
    echo '{'
    echo "  \"name\": \"isplt-plt-${case}\","
    echo '  "resources": {'
    local parts=()
    while [[ $# -gt 0 ]]; do
      parts+=("$1")
      shift
    done
    local IFS=$',\n'
    echo "${parts[*]}"
    echo '  }'
    echo '}'
  } > "$file"
  echo "wrote $file"
}

mkdir -p permissions/platform

write_case B lab-plt-b "$(artifact_targets_all lab-plt-b)"
write_case C lab-plt-c "$(build_read lab-plt-c)"
write_case D lab-plt-d "$(artifact_targets_all lab-plt-d)"
write_case E lab-plt-e "$(build_read lab-plt-e)"
write_case F lab-plt-f "$(artifact_targets_all lab-plt-f),$(build_read lab-plt-f)"
write_case G lab-plt-g "$(artifact_targets_all lab-plt-g),$(build_read lab-plt-g)"
write_case H lab-plt-h "$(artifact_targets_npm_only lab-plt-h),$(build_read lab-plt-h)"
write_case I lab-plt-i "$(artifact_targets_all lab-plt-i),$(build_read lab-plt-i 'isplt-lab**/**')"

# Case A: no Access permission target (Xray role only) — empty marker file
echo '{"name":"isplt-plt-A","note":"No artifact/build grants; assign Manage Reports on user only"}' \
  > permissions/platform/case-A.json

echo "Done. Assign xray_global_roles per permissions/users/*.json in apply runbook."
