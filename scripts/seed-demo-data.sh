#!/usr/bin/env bash
# Development only: puts demo data into the database of a running API (through the API itself, so every rule applies).
#
#   demo parent : demo@dandoona.app  /  Demo!2026x
#   child Sara  : finished EVERY lesson and activity (Letters A-Z and all 10 Colors) -> both units done, both certificates
#   child Adam  : finished Letters A-M only -> Letters is the current unit
#
# Usage: scripts/seed-demo-data.sh [base-url]      (default http://localhost:5080)
# Safe to run again: existing accounts/children are reused and progress uses fixed record ids (duplicates are ignored).
set -euo pipefail

BASE="${1:-http://localhost:5080}"
EMAIL="demo@dandoona.app"
PASSWORD='Demo!2026x'
YEAR=$(date +%Y)

json_field() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -1; }

echo "Seeding $BASE as $EMAIL"
reg=$(curl -s -o /tmp/seed_reg.json -w '%{http_code}' -X POST "$BASE/api/auth/register" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"displayName\":\"Demo Parent\",\"guardianConfirmed\":true,\"termsAccepted\":true}")
if [ "$reg" = "200" ]; then token=$(json_field accessToken </tmp/seed_reg.json); echo "  parent created"; else
  token=$(curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | json_field accessToken)
  echo "  parent already exists, signed in"
fi
[ -n "$token" ] || { echo "could not sign in"; exit 1; }
auth=(-H "Authorization: Bearer $token" -H 'Content-Type: application/json')

# create the child unless one with that name exists; print its id
child_id() { # name avatar birthYear
  local existing
  existing=$(curl -s "${auth[@]}" "$BASE/api/children" | tr '{' '\n' | grep "\"name\":\"$1\"" | json_field id || true)
  if [ -n "$existing" ]; then echo "$existing"; return; fi
  curl -s -X POST "${auth[@]}" "$BASE/api/children" -d "{\"name\":\"$1\",\"avatarKey\":\"$2\",\"birthYear\":$3,\"track\":\"little-learners\"}" | json_field id
}

LETTERS=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
COLORS=(red blue yellow green orange purple pink brown black white)

# progress items for the lessons given as arguments; $1 = child tag (keeps record ids unique per child)
items() {
  local tag="$1"; shift
  local n=0 out=""
  for lesson in "$@"; do
    case "$lesson" in
      letter-*) acts="trace listen-and-tap record-and-listen match-picture" ;;
      *)        acts="listen-and-tap match-picture record-and-listen color-the-object" ;;
    esac
    for act in $acts; do
      n=$((n + 1))
      # fixed, valid GUID per (child, record) so running the script twice stores nothing twice
      guid=$(printf '%08x-%04x-4000-8000-%012x' $((0xD0000000 + tag)) "$tag" "$n")
      stars=3; [ $((n % 7)) -eq 0 ] && stars=2
      day=$(( (n / 24) + 1 )); hour=$(( 8 + (n % 12) ))
      when=$(printf '%s-09-%02dT%02d:%02d:00Z' "$YEAR" "$day" "$hour" $((n % 60)))
      out="$out{\"clientRecordId\":\"$guid\",\"lessonId\":\"$lesson\",\"activity\":\"$act\",\"stars\":$stars,\"attempts\":$((4 - stars + 1)),\"timeSpentSeconds\":$((30 + n % 40)),\"completedAt\":\"$when\"},"
    done
  done
  echo "[${out%,}]"
}

submit() { # childId tag lessons...
  local id="$1" tag="$2"; shift 2
  local payload; payload="{\"items\":$(items "$tag" "$@")}"
  curl -s -X POST "${auth[@]}" "$BASE/api/children/$id/progress" -d "$payload"; echo
}

sara=$(child_id Sara rocket $((YEAR - 5)))
all=(); for l in "${LETTERS[@]}"; do all+=("letter-$l"); done; for c in "${COLORS[@]}"; do all+=("color-$c"); done
echo -n "  Sara ($sara), all ${#all[@]} lessons: "; submit "$sara" 1 "${all[@]}"

adam=$(child_id Adam cloud $((YEAR - 4)))
some=(); for l in a b c d e f g h i j k l m; do some+=("letter-$l"); done
echo -n "  Adam ($adam), Letters A-M: "; submit "$adam" 2 "${some[@]}"

echo "Done. In the app: sign in with $EMAIL / $PASSWORD"
