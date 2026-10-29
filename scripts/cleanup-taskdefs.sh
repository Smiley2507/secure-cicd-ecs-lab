#!/usr/bin/env bash
set -euo pipefail

family="${1:?usage: cleanup-taskdefs.sh <family> [keep]}"
keep="${2:-3}"
: "${AWS_REGION:?}" "${ECS_CLUSTER:?}" "${ECS_SERVICE:?}"

in_use=$(aws ecs describe-services --region "$AWS_REGION" \
    --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" \
    --query 'services[0].taskDefinition' --output text)

# --family-prefix also matches weather-app-bootstrap (owned by Terraform), so keep exact-family ARNs only.
mapfile -t revisions < <(
    aws ecs list-task-definitions --region "$AWS_REGION" \
        --family-prefix "$family" --status ACTIVE --sort DESC \
        --query 'taskDefinitionArns[]' --output text \
    | tr '\t' '\n' | grep -E ":task-definition/${family}:[0-9]+$" || true
)

echo "Family $family: ${#revisions[@]} active revision(s), keeping $keep. In use: ${in_use##*/}"

for arn in "${revisions[@]:$keep}"; do
    if [[ "$arn" == "$in_use" ]]; then
        echo "  keep  ${arn##*/} (in use)"
        continue
    fi
    aws ecs deregister-task-definition --region "$AWS_REGION" \
        --task-definition "$arn" --query 'taskDefinition.status' --output text \
        | sed "s|^|  ${arn##*/} -> |"
done
