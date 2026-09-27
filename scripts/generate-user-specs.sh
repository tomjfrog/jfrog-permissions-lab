#!/usr/bin/env bash
# Generate persona specs. `.user` is the body for POST /access/api/v2/users (add a password at apply time).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p permissions/users

write_user() {
  local user=$1 case=$2 reports=$3 extras=$4 perm=$5
  jq -n \
    --arg u "$user" \
    --arg mc "$case" \
    --argjson reports "$reports" \
    --argjson extras "$extras" \
    --arg perm "$perm" \
    '{
      matrix_case: $mc,
      access_permission: (if $perm == "none" then null else $perm end),
      user: {
        username: $u,
        email: ($u + "@labs.invalid"),
        admin: false,
        groups: [],
        reports_manager: $reports,
        watch_manager: $extras,
        policy_manager: $extras
      }
    }' > "permissions/users/${user}.json"
}

#          user               case           reports extras permission
write_user lab-plt-a          A              true    false  none
write_user lab-plt-b          B              false   false  permissions/platform/case-B.json
write_user lab-plt-c          C              false   false  permissions/platform/case-C.json
write_user lab-plt-d          D              true    false  permissions/platform/case-D.json
write_user lab-plt-e          E              true    false  permissions/platform/case-E.json
write_user lab-plt-f          F              true    false  permissions/platform/case-F.json
write_user lab-plt-g          G              true    true   permissions/platform/case-G.json
write_user lab-plt-h          H              true    false  permissions/platform/case-H.json
write_user lab-plt-i          I              true    false  permissions/platform/case-I.json

# Project personas get Xray rights only through their project role.
write_user lab-prj-full       prj_full       false   false  none
write_user lab-prj-noreports  prj_noreports  false   false  none
write_user lab-prj-nobuild    prj_nobuild    false   false  none
write_user lab-prj-noartifact prj_noartifact false   false  none
write_user lab-prj-developer  prj_developer  false   false  none

echo "Wrote permissions/users/*.json"
