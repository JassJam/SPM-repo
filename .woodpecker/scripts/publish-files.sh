#!/bin/sh
set -eu

: "${SPM_FILES:?SPM_FILES is required}"
: "${FORGE_TOKEN:?FORGE_TOKEN is required}"
: "${SPM_CHECKSUM:=sha256}"
: "${FORGE_URL:=$CI_FORGE_URL}"
: "${FORGE_REPO:=$CI_REPO}"

API="$FORGE_URL/api/v1/repos/$FORGE_REPO"
AUTH="Authorization: token $FORGE_TOKEN"

for f in $SPM_FILES; do
  [ -f "$f" ] || { echo "MISSING: $f"; exit 1; }
done

UPLOAD="$SPM_FILES"
if [ "$SPM_CHECKSUM" != "none" ]; then
  # shellcheck disable=SC2086
  "${SPM_CHECKSUM}sum" $SPM_FILES > "spm.$SPM_CHECKSUM"
  UPLOAD="$UPLOAD spm.$SPM_CHECKSUM"
  cat "spm.$SPM_CHECKSUM"
fi

RID=$(curl -s -H "$AUTH" "$API/releases/tags/$CI_COMMIT_TAG" | jq -r '.id? // empty')

if [ -z "$RID" ]; then
  echo "Creating release $CI_COMMIT_TAG"
  code=$(curl -s -o /tmp/release.json -w '%{http_code}' -X POST \
    -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$CI_COMMIT_TAG\",\"name\":\"$CI_COMMIT_TAG\"}" \
    "$API/releases")
  if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
    echo "Release creation failed: HTTP $code"
    cat /tmp/release.json; echo
    exit 1
  fi
  RID=$(jq -r '.id' /tmp/release.json)
fi

[ -n "$RID" ] && [ "$RID" != "null" ] || { echo "No release id"; exit 1; }
echo "Using release id $RID"

for f in $UPLOAD; do
  name=$(basename "$f")

  OLD=$(curl -s -H "$AUTH" "$API/releases/$RID/assets" \
    | jq -r --arg n "$name" 'if type == "array" then .[] | select(.name == $n) | .id else empty end')
  for id in $OLD; do
    echo "Deleting existing asset $name ($id)"
    curl -s -o /dev/null -X DELETE -H "$AUTH" "$API/releases/$RID/assets/$id"
  done

  echo "Uploading $name"
  code=$(curl -s -o /tmp/resp.json -w '%{http_code}' -X POST -H "$AUTH" \
    -F "attachment=@$f" "$API/releases/$RID/assets?name=$name")
  if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
    echo "Upload of $name failed: HTTP $code"
    cat /tmp/resp.json; echo
    exit 1
  fi
done

echo "Published $CI_COMMIT_TAG"