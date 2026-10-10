#!/usr/bin/env bash
# Dev only: runs the onboarding on the emulator for the design review.
#   tools/onboard-demo.sh <en|ar> <name> <year> <skill label...>     (labels as shown on the screen; "NONE" = tap none-of-these)
# Leaves the app on the summary; screenshots go to dist/review/skills/<lang>-<name>-*.png
set -e
U="node tools/adb-ui.mjs"; ADB=/c/src/android-sdk/platform-tools/adb.exe
LANGUAGE=$1; NAME=$2; YEAR=$3; shift 3
O=dist/review/skills; mkdir -p $O
MSYS_NO_PATHCONV=1 $ADB shell pm clear com.dandoona.kids_english_app >/dev/null
MSYS_NO_PATHCONV=1 $ADB shell monkey -p com.dandoona.kids_english_app -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 17
if [ "$LANGUAGE" = ar ]; then $U tap "العربية" >/dev/null; sleep 0.6; fi
$U tapat 540 2222 >/dev/null; sleep 2.2       # continue (language)
$U tapat 540 2222 >/dev/null; sleep 2.5       # continue (welcome)
$U tapat 540 985 >/dev/null; sleep 0.5; $U type "$NAME." >/dev/null; MSYS_NO_PATHCONV=1 $ADB shell input keyevent 67; sleep 1; $U tapat 540 400 >/dev/null; sleep 0.8
$U tapat 425 1312 >/dev/null; sleep 0.3       # an avatar (bunny)
$U tapat 540 2222 >/dev/null; sleep 2.5       # continue (name)
$U tapat 540 1381 >/dev/null; sleep 1; $U tapat 546 930 >/dev/null; sleep 0.8   # month: second item
$U tapat 540 1575 >/dev/null; sleep 1
case $YEAR in 2022) Y=1056;; 2021) Y=1182;; 2019) Y=1434;; 2018) Y=1560;; *) Y=1056;; esac
$U tapat 546 $Y >/dev/null; sleep 0.8
$U tapat 540 2222 >/dev/null; sleep 2.5       # continue (age)
# skills: scroll until each label is found
for LABEL in "$@"; do
  for i in 1 2 3 4; do
    if $U tap "$LABEL" >/dev/null 2>&1; then break; fi
    $U swipe up >/dev/null; sleep 0.4
  done
  sleep 0.4
done
$U shot $O/$LANGUAGE-$NAME-skills.png >/dev/null
$U tapat 540 2222 >/dev/null; sleep 2.3       # continue (skills)
$U tapat 540 1494 >/dev/null; sleep 0.5; $U tapat 540 2222 >/dev/null; sleep 2.3   # goal: the middle card
$U tapat 540 2211 >/dev/null; sleep 2.8       # "remind me later"
$U shot $O/$LANGUAGE-$NAME-summary.png >/dev/null
