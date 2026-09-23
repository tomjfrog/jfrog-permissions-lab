#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p permissions/users

write_user() {
  local user=$1 case=$2 mr=$3 perm=$4
  local roles='[]'
  [[ "$mr" == "yes" ]] && roles='["Manage Reports"]'
  jq -n \
    --arg u "$user" \
    --arg mc "$case" \
    --argjson roles "$roles" \
    --arg perm "$perm" \
    '{
      username: $u,
      email: ($u + "@labs.invalid"),
      admin: false,
      matrix_case: $mc,
      xray_global_roles: $roles,
      access_permission: (if $perm == "none" then null else $perm end)
    }' > "permissions/users/${user}.json"
}

write_user lab-plt-a A yes none
write_user lab-plt-b B no permissions/platform/case-B.json
write_user lab-plt-c C no permissions/platform/case-C.json
write_user lab-plt-d D yes permissions/platform/case-D.json
write_user lab-plt-e E yes permissions/platform/case-E.json
write_user lab-plt-f F yes permissions/platform/case-F.json
write_user lab-plt-g G yes permissions/platform/case-G.json
write_user lab-plt-h H yes permissions/platform/case-H.json
write_user lab-plt-i I yes permissions/platform/case-I.json

write_user lab-prj-full prj_full no none
write_user lab-prj-noreports prj_noreports no none
write_user lab-prj-nobuild prj_nobuild no none
write_user lab-prj-noartifact prj_noartifact no none
write_user lab-prj-developer prj_developer no none

echo "Wrote permissions/users/*.json"
