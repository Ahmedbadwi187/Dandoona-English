#!/usr/bin/env bash
# Development only: puts demo data into the database of a running API (through the API itself, so every rule applies).
#
#   demo parent : demo@dandoona.app  /  Demo!2026x
#   child Sara  : finished EVERY lesson and activity (Letters A-Z and all 10 Colors) -> both units done, both certificates
#   child Adam  : finished Letters A-M only -> Letters is the current unit
#   child Noor  : finished the WHOLE course (all 15 units, every lesson and activity), with every certificate, every treasure chest
#                 opened (all 15 outfits and all stickers), the three reviews and the castle passed -> the map from start to finish
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
child_id() { # name avatar birthYear [track] [birthMonth]
  local existing month=""
  existing=$(curl -s "${auth[@]}" "$BASE/api/children" | tr '{' '\n' | grep "\"name\":\"$1\"" | json_field id || true)
  if [ -n "$existing" ]; then echo "$existing"; return; fi
  [ -n "${5:-}" ] && month=",\"birthMonth\":$5"
  curl -s -X POST "${auth[@]}" "$BASE/api/children" -d "{\"name\":\"$1\",\"avatarKey\":\"$2\",\"birthYear\":$3,\"track\":\"${4:-little-learners}\"$month}" | json_field id
}

# The games of a lesson, read from its own file (used for the Explorers child, so the demo follows the content).
ROOT0="$(cd "$(dirname "$0")/.." && pwd)"
acts_of() { sed -n 's/^activities: \[\(.*\)\]\r*$/\1/p' "$ROOT0/content/curriculum/$1.yaml" | tr -d ','; }

LETTERS=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
COLORS=(red blue yellow green orange purple pink brown black white)

# progress items for the lessons given as arguments; $1 = child tag (keeps record ids unique per child)
items() {
  local tag="$1"; shift
  local n=${N0:-0} out=""
  for lesson in "$@"; do
    if [ -n "${FROM_FILES:-}" ]; then
      acts="$(acts_of "$lesson")"
    else
      case "$lesson" in
        letter-*) acts="trace trace-small listen-and-tap record-and-listen match-picture" ;;
        actions-*) acts="listen-and-tap match-picture dandoona-says record-and-listen" ;;
        animals-*) acts="listen-and-tap match-picture animal-sounds habitat record-and-listen" ;;
        color-*)  acts="listen-and-tap match-picture record-and-listen color-the-object" ;;
        *)        acts="listen-and-tap match-picture record-and-listen" ;;
      esac
    fi
    for act in $acts; do
      n=$((n + 1))
      # fixed, valid GUID per (child, record) so running the script twice stores nothing twice
      guid=$(printf '%08x-%04x-4000-8000-%012x' $((0xD0000000 + tag)) "$tag" "$n")
      stars=3; [ $((n % 7)) -eq 0 ] && stars=2
      day=$(( ((n / 24) % 28) + 1 )); hour=$(( 8 + (n % 12) ))
      when=$(printf '%s-09-%02dT%02d:%02d:00Z' "$YEAR" "$day" "$hour" $((n % 60)))
      out="$out{\"clientRecordId\":\"$guid\",\"lessonId\":\"$lesson\",\"activity\":\"$act\",\"stars\":$stars,\"attempts\":$((4 - stars + 1)),\"timeSpentSeconds\":$((30 + n % 40)),\"completedAt\":\"$when\"},"
    done
  done
  echo "[${out%,}]"
}

submit() { # childId tag lessons...  (the server takes at most 200 records at a time: 40 lessons per request)
  local id="$1" tag="$2" k=0; shift 2
  while [ $# -gt 0 ]; do
    local chunk=("${@:1:40}"); shift ${#chunk[@]}
    N0=$((k * 1000)) submit_chunk "$id" "$tag" "${chunk[@]}"; k=$((k + 1))
  done
}

submit_chunk() { # childId tag lessons...
  local id="$1" tag="$2"; shift 2
  # through a file: the whole course is too long for a command line
  printf '{"items":%s}' "$(items "$tag" "$@")" > /tmp/seed_payload.json
  curl -s -X POST "${auth[@]}" "$BASE/api/children/$id/progress" --data-binary @/tmp/seed_payload.json; echo
}

sara=$(child_id Sara rocket $((YEAR - 5)))
all=(); for l in "${LETTERS[@]}"; do all+=("letter-$l"); done; for c in "${COLORS[@]}"; do all+=("color-$c"); done
echo -n "  Sara ($sara), all ${#all[@]} lessons: "; submit "$sara" 1 "${all[@]}"

adam=$(child_id Adam cloud $((YEAR - 4)))
some=(); for l in a b c d e f g h i j k l m; do some+=("letter-$l"); done
echo -n "  Adam ($adam), Letters A-M: "; submit "$adam" 2 "${some[@]}"

# Noor: the whole course. Every lesson file of the repo is a lesson id; the units are the ones of the map.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNITS=(letters colors numbers shapes animals feelings my-body actions food clothes toys my-family my-home opposites transport)
noor=$(child_id Noor bunny $((YEAR - 4)))
course=(); for f in "$ROOT"/content/curriculum/*.yaml; do grep -q '^track: little-learners' "$f" && course+=("$(basename "$f" .yaml)"); done
echo -n "  Noor ($noor), all ${#course[@]} lessons of the course: "; submit "$noor" 3 "${course[@]}"

# every certificate and chest (one per unit), the three reviews and the castle
ach=""; i=0
for u in "${UNITS[@]}"; do
  i=$((i + 1)); day=$(( (i % 28) + 1 ))
  when=$(printf '%s-09-%02dT12:00:00Z' "$YEAR" "$day")
  ach="$ach{\"kind\":\"certificate\",\"key\":\"$u\",\"earnedAt\":\"$when\"},{\"kind\":\"chest\",\"key\":\"$u\",\"earnedAt\":\"$when\"},"
done
for r in review-1 review-2 review-3 castle; do ach="$ach{\"kind\":\"review\",\"key\":\"$r\",\"earnedAt\":\"${YEAR}-09-28T12:00:00Z\"},"; done
echo -n "  Noor, certificates + chests + reviews + castle: "
curl -s -X POST "${auth[@]}" "$BASE/api/children/$noor/achievements" -d "{\"items\":[${ach%,}]}"; echo

# Lina: an Explorers child (7 years old) who finished the whole Explorers track. Her map starts with the Little Learners Letters unit
# (so the 26 letter lessons count), then the 12 Explorers units; every game of every lesson comes from the lesson files.
EXPLORER_UNITS=(letters sound-builders digraphs blends magic-e vowel-teams sight-words-1 sight-words-2 my-sentences word-families everyday-english numbers-time grammar-starters)
lina=$(child_id Lina flower $((YEAR - 7)) explorers 5)
trackcourse=(); for f in "$ROOT"/content/curriculum/*.yaml; do b=$(basename "$f" .yaml); if grep -q '^track: explorers' "$f" || [[ "$b" == letter-* ]]; then trackcourse+=("$b"); fi; done
echo -n "  Lina ($lina), all ${#trackcourse[@]} lessons of Explorers: "; FROM_FILES=1 submit "$lina" 4 "${trackcourse[@]}"
ach=""; i=0
for u in "${EXPLORER_UNITS[@]}"; do
  i=$((i + 1)); day=$(( (i % 28) + 1 ))
  when=$(printf '%s-09-%02dT12:00:00Z' "$YEAR" "$day")
  ach="$ach{\"kind\":\"certificate\",\"key\":\"$u\",\"earnedAt\":\"$when\"},{\"kind\":\"chest\",\"key\":\"$u\",\"earnedAt\":\"$when\"},{\"kind\":\"story\",\"key\":\"$u\",\"earnedAt\":\"$when\"},"
done
for r in review-1 review-2 review-3 review-4 castle; do ach="$ach{\"kind\":\"review\",\"key\":\"$r\",\"earnedAt\":\"${YEAR}-09-29T12:00:00Z\"},"; done
echo -n "  Lina, certificates + chests + stories + reviews + castle: "
curl -s -X POST "${auth[@]}" "$BASE/api/children/$lina/achievements" -d "{\"items\":[${ach%,}]}"; echo

echo "Done. In the app: sign in with $EMAIL / $PASSWORD"
