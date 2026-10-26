#!/bin/sh
set -eu

#!/bin/sh
set -eu

: "${SPM_FILES:?SPM_FILES is required}"
: "${FORGE_TOKEN:?FORGE_TOKEN is required}"
: "${SPM_CHECKSUM:=sha256}"
: "${SPM_ONLY_IF_CHANGED:=true}"
: "${SPM_DRY_RUN:=false}"
: "${FORGE_URL:=$CI_FORGE_URL}"
: "${FORGE_REPO:=$CI_REPO}"

if [ -z "${CI_COMMIT_TAG:-}" ]; then
  CI_COMMIT_TAG="test-$(printf %s "$CI_COMMIT_SHA" | cut -c1-8)"
  echo "Not a tag event, using test tag: $CI_COMMIT_TAG"
  SPM_DRY_RUN=true
fi

git config --global --add safe.directory "$CI_WORKSPACE"
git fetch --tags --force --unshallow 2>/dev/null || git fetch --tags --force

if [ "$SPM_ONLY_IF_CHANGED" = "true" ]; then
  PREV=$(git describe --tags --abbrev=0 "$CI_COMMIT_TAG^" 2>/dev/null || true)
  if [ -n "$PREV" ]; then
    # shellcheck disable=SC2086
    CHANGED=$(git diff --name-only "$PREV" "$CI_COMMIT_TAG" -- $SPM_FILES)
    if [ -z "$CHANGED" ]; then
      echo "No files changed since $PREV, nothing to publish."
      exit 0
    fi
    echo "Changed since $PREV:"; echo "$CHANGED"
  fi
fi

if [ "$SPM_DRY_RUN" = "true" ]; then
  echo "DRY RUN: would publish to release $CI_COMMIT_TAG:"
  for f in $SPM_FILES; do
    [ -f "$f" ] || { echo "MISSING: $f"; exit 1; }
    echo "  $(basename "$f")"
  done
  if [ "$SPM_CHECKSUM" != "none" ]; then
    # shellcheck disable=SC2086
    "${SPM_CHECKSUM}sum" $SPM_FILES
  fi
 # exit 0
fi

RID=$(curl -s -H "$AUTH" "$API/releases/tags/$CI_COMMIT_TAG" | jq -r '.id // empty')
if [ -z "$RID" ]; then
  RID=$(curl -sf -X POST -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"$CI_COMMIT_TAG\",\"name\":\"$CI_COMMIT_TAG\"}" \
    "$API/releases" | jq -r '.id')
fi

UPLOAD="$SPM_FILES"
if [ "$SPM_CHECKSUM" != "none" ]; then
  # shellcheck disable=SC2086
  "${SPM_CHECKSUM}sum" $SPM_FILES > "spm.$SPM_CHECKSUM"
  UPLOAD="$UPLOAD spm.$SPM_CHECKSUM"
fi

for f in $UPLOAD; do
  name=$(basename "$f")

  OLD=$(curl -s -H "$AUTH" "$API/releases/$RID/assets" \
    | jq -r --arg n "$name" '.[]? | select(.name == $n) | .id')
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
