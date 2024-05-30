#!/bin/bash

# Default values
IMAGE_PATH=""
WEBHOOK_URL=""
STATUS=""

# Parse options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --image) IMAGE_PATH="$2"; shift ;;
    --webhook) WEBHOOK_URL="$2"; shift ;;
    --status) STATUS="$2"; shift ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

# Check if necessary parameters are provided
if [ -z "$WEBHOOK_URL" ]; then
  echo -e "ERROR: You need to provide the webhook URL with --webhook."
  exit 1
fi

if [ -z "$STATUS" ]; then
  echo -e "ERROR: You need to provide the status with --status."
  exit 1
fi

case $STATUS in
  "success" )
    EMBED_COLOR=3066993
    STATUS_MESSAGE="Passed"
    ARTIFACT_URL="$CI_JOB_URL/artifacts/download"
    ;;

  "failure" )
    EMBED_COLOR=15158332
    STATUS_MESSAGE="Failed"
    ARTIFACT_URL="Not available"
    ;;

  "waiting" )
    EMBED_COLOR=16705372
    STATUS_MESSAGE="Waiting for Approval"
    ARTIFACT_URL="Not available"
    ACTION="> [Click to trigger manual deployment]($CI_PIPELINE_URL)"
    ;;
  
  * )
    EMBED_COLOR=0
    STATUS_MESSAGE="Status Unknown"
    ARTIFACT_URL="Not available"
    ;;
esac

AUTHOR_NAME="$(git log -1 "$CI_COMMIT_SHA" --pretty="%aN")"
COMMITTER_NAME="$(git log -1 "$CI_COMMIT_SHA" --pretty="%cN")"
COMMIT_SUBJECT="$(git log -1 "$CI_COMMIT_SHA" --pretty="%s")"
COMMIT_MESSAGE="$(git log -1 "$CI_COMMIT_SHA" --pretty="%b")" | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g'

if [ "$AUTHOR_NAME" == "$COMMITTER_NAME" ]; then
  CREDITS="$AUTHOR_NAME authored & committed"
else
  CREDITS="$AUTHOR_NAME authored & $COMMITTER_NAME committed"
fi

if [ -z $CI_MERGE_REQUEST_ID ]; then
  URL=""
else
  URL="$CI_PROJECT_URL/merge_requests/$CI_MERGE_REQUEST_ID"
fi

TIMESTAMP=$(date --utc +%FT%TZ)

IMAGE_FILE_NAME=$(basename "$IMAGE_PATH")

if [ -z $IMAGE_FILE_NAME ]; then
  IMAGE_FIELD=""
else
  IMAGE_FIELD='"image":{"url": "attachment://'$IMAGE_FILE_NAME'"},'
fi

if [ -z "$IMAGE_PATH" ]; then
  WEBHOOK_DATA='{
    "avatar_url": "https://gitlab.com/favicon.png",
    "embeds": [ {
      "color": '$EMBED_COLOR',
      "author": {
        "name": "Pipeline #'"$CI_PIPELINE_IID"' '"$STATUS_MESSAGE"' - '"$CI_PROJECT_PATH_SLUG"'",
        "url": "'"$CI_PIPELINE_URL"'",
        "icon_url": "https://gitlab.com/favicon.png"
      },
      "title": "'"$COMMIT_SUBJECT"'",
      "url": "'"$URL"'",
      "description": "'"${COMMIT_MESSAGE//$'\n'/ }"\\n\\n"${CREDITS//$'\n'/ }"\\n\\n"$ACTION"'",
      '$IMAGE_FIELD'
      "fields": [
        {
          "name": "Commit",
          "value": "'"[\`$CI_COMMIT_SHORT_SHA\`]($CI_PROJECT_URL/commit/$CI_COMMIT_SHA)"'",
          "inline": true
        },
        {
          "name": "Branch",
          "value": "'"[\`$CI_COMMIT_REF_NAME\`]($CI_PROJECT_URL/tree/$CI_COMMIT_REF_NAME)"'",
          "inline": true
        }
        ],
        "timestamp": "'"$TIMESTAMP"'"
      } ]
    }'
else
  WEBHOOK_DATA='{
    "avatar_url": "https://gitlab.com/favicon.png",
    "embeds": [ {
      "color": '$EMBED_COLOR',
      "author": {
        "name": "Pipeline #'"$CI_PIPELINE_IID"' '"$STATUS_MESSAGE"' - '"$CI_PROJECT_PATH_SLUG"'",
        "url": "'"$CI_PIPELINE_URL"'",
        "icon_url": "https://gitlab.com/favicon.png"
      },
      "title": "'"$COMMIT_SUBJECT"'",
      "url": "'"$URL"'",
      "description": "'"${COMMIT_MESSAGE//$'\n'/ }"\\n\\n"${CREDITS//$'\n'/ }"\\n\\n"$ACTION"\\n\\n""'",
      '$IMAGE_FIELD'
      "fields": [
        {
          "name": "Commit",
          "value": "'"[\`$CI_COMMIT_SHORT_SHA\`]($CI_PROJECT_URL/commit/$CI_COMMIT_SHA)"'",
          "inline": true
        },
        {
          "name": "Branch",
          "value": "'"[\`$CI_COMMIT_REF_NAME\`]($CI_PROJECT_URL/tree/$CI_COMMIT_REF_NAME)"'",
          "inline": true
        },
        {
          "name": "Artifacts",
          "value": "'"[\`$CI_JOB_ID\`]($ARTIFACT_URL)"'",
          "inline": true
        }
      ],
      "timestamp": "'"$TIMESTAMP"'"
    } ]
  }'
fi

echo -e "[Webhook]: Sending webhook to Discord...\n"

if [ -z "$IMAGE_PATH" ]; then
  (curl --fail --progress-bar -A "GitLabCI-Webhook" -H X-Author:k3rn31p4nic#8383 -F "payload_json=$WEBHOOK_DATA" "$WEBHOOK_URL" \
  && echo -e "\n[Webhook]: Successfully sent the webhook.") || echo -e "\n[Webhook]: Unable to send webhook."
else
  (curl --fail --progress-bar -A "GitLabCI-Webhook" -H X-Author:k3rn31p4nic#8383 -F "payload_json=$WEBHOOK_DATA" -F "file1=@$IMAGE_PATH" "$WEBHOOK_URL" \
  && echo -e "\n[Webhook]: Successfully sent the webhook.") || echo -e "\n[Webhook]: Unable to send webhook."
fi
