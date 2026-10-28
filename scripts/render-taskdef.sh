#!/usr/bin/env bash
set -euo pipefail

out="${1:?usage: render-taskdef.sh <output.json>}"
template="$(dirname "$0")/../ecs/taskdef.template.json"
vars=(TASK_FAMILY IMAGE_URI APP_VERSION EXEC_ROLE_ARN TASK_ROLE_ARN LOG_GROUP AWS_REGION)

for v in "${vars[@]}"; do
    if [[ -z "${!v:-}" ]]; then
        echo "render-taskdef: $v is not set" >&2
        exit 1
    fi
done

envsubst "$(printf '${%s} ' "${vars[@]}")" < "$template" > "$out"

jq -e . "$out" > /dev/null
if grep -q '\${' "$out"; then
    echo "render-taskdef: unrendered placeholder in $out" >&2
    exit 1
fi

echo "Rendered $out -> $(jq -r '.containerDefinitions[0].image' "$out")"
