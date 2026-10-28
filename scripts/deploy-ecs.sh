#!/usr/bin/env bash
# Register a rendered task definition and roll the ECS service onto it.
#
#   scripts/deploy-ecs.sh <rendered-taskdef.json> <evidence-dir>
#
# Needs ECS_CLUSTER, ECS_SERVICE and AWS_REGION in the environment.
set -euo pipefail

taskdef="${1:?usage: deploy-ecs.sh <taskdef.json> <evidence-dir>}"
evidence="${2:?usage: deploy-ecs.sh <taskdef.json> <evidence-dir>}"
: "${ECS_CLUSTER:?}" "${ECS_SERVICE:?}" "${AWS_REGION:?}"
mkdir -p "$evidence"

new_arn=$(aws ecs register-task-definition \
    --region "$AWS_REGION" \
    --cli-input-json "file://$taskdef" \
    --query 'taskDefinition.taskDefinitionArn' --output text)
echo "Registered $new_arn"
echo "$new_arn" > "$evidence/taskdef-arn.txt"

aws ecs update-service \
    --region "$AWS_REGION" \
    --cluster "$ECS_CLUSTER" \
    --service "$ECS_SERVICE" \
    --task-definition "$new_arn" \
    --query 'service.deployments[0].[id,status,rolloutState]' --output text

# Polls every 15s for up to 10 minutes until there is one deployment and
# runningCount == desiredCount.
echo "Waiting for the service to stabilise..."
wait_rc=0
aws ecs wait services-stable \
    --region "$AWS_REGION" \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" || wait_rc=$?

aws ecs describe-services \
    --region "$AWS_REGION" \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" > "$evidence/describe-services.json"

if [[ $wait_rc -ne 0 ]]; then
    echo "Service did not stabilise (waiter exit $wait_rc)" >&2
    exit 1
fi

# "Stable" is not the same as "deployed": if the circuit breaker rolled back,
# the service is stable — on the OLD revision. Check what is actually primary.
primary=$(jq -r '.services[0].deployments[] | select(.status == "PRIMARY")' "$evidence/describe-services.json")
primary_arn=$(jq -r '.taskDefinition' <<<"$primary")
rollout=$(jq -r '.rolloutState' <<<"$primary")

echo "Primary deployment: $primary_arn ($rollout)"
if [[ "$primary_arn" != "$new_arn" || "$rollout" != "COMPLETED" ]]; then
    echo "Deployment of $new_arn did not complete — ECS rolled back or is still rolling." >&2
    jq -r '.services[0].events[:10][] | "\(.createdAt)  \(.message)"' "$evidence/describe-services.json" >&2
    exit 1
fi

jq -r '.services[0].events[:5][] | "\(.createdAt)  \(.message)"' "$evidence/describe-services.json"
