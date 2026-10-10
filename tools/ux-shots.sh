#!/usr/bin/env bash
# Dev only: walks the first-run flow on the emulator and screenshots every page, for the ChatGPT design review.
#   tools/ux-shots.sh <en|ar>      ->  dist/review/ux/<lang>/NN-page.png
set -e
U="node tools/adb-ui.mjs"; ADB=/c/src/android-sdk/platform-tools/adb.exe
L=${1:-en}; O=dist/review/ux/$L; rm -rf $O; mkdir -p $O
n=0; shot() { n=$((n+1)); $U shot "$O/$(printf %02d $n)-$1.png" >/dev/null; }
MSYS_NO_PATHCONV=1 $ADB shell pm clear com.dandoona.kids_english_app >/dev/null
MSYS_NO_PATHCONV=1 $ADB shell monkey -p com.dandoona.kids_english_app -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 17
if [ "$L" = ar ]; then $U tap "العربية" >/dev/null; sleep 0.6; fi
shot language
$U tapat 540 2222 >/dev/null; sleep 2.5; shot welcome
$U tapat 540 2222 >/dev/null; sleep 2.5; shot child-name-avatar
$U tapat 540 985 >/dev/null; sleep 0.5; $U type "Yaraa" >/dev/null; MSYS_NO_PATHCONV=1 $ADB shell input keyevent 67; sleep 1; $U tapat 540 400 >/dev/null; sleep 0.8
$U tapat 425 1312 >/dev/null; sleep 0.3; shot child-name-filled
$U tapat 540 2222 >/dev/null; sleep 2.5; shot child-age
$U tapat 540 1381 >/dev/null; sleep 1; $U tapat 546 930 >/dev/null; sleep 0.8
$U tapat 540 1575 >/dev/null; sleep 1; $U tapat 546 1434 >/dev/null; sleep 0.8; shot child-age-filled
$U tapat 540 2222 >/dev/null; sleep 2.5; shot skills-top
$U swipe up >/dev/null; sleep 0.6; shot skills-middle
$U swipe up >/dev/null; sleep 0.6; shot skills-bottom
$U tap "$([ $L = ar ] && echo 'لا شيء' || echo 'None')" >/dev/null 2>&1 || true; sleep 0.5; shot skills-chosen
$U tapat 540 2222 >/dev/null; sleep 2.3; shot goal
$U tapat 540 1494 >/dev/null; sleep 0.5; $U tapat 540 2222 >/dev/null; sleep 2.3; shot reminder
$U tapat 540 2211 >/dev/null; sleep 2.8; shot summary
echo "$n screenshots in $O"
