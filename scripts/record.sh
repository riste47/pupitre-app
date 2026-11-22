#!/bin/bash
# Démarre un iPhone puis un iPad simulés, installe Pupitre, le lance en mode « visite » (-tour) et filme ~20 s.
set -u
APP=$(find build/Build/Products -name "Pupitre.app" -type d | head -1)
mkdir -p out
pick() { xcrun simctl list devices available | grep -E "^\s+$1" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'; }
for KIND in "iPhone" "iPad"; do
  UDID=$(pick "$KIND")
  [ -z "$UDID" ] && { echo "Aucun simulateur $KIND"; continue; }
  NAME=$(echo "$KIND" | tr '[:upper:]' '[:lower:]')
  echo "▶︎ $KIND ($UDID)"
  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
  xcrun simctl ui "$UDID" appearance light || true
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "out/pupitre-$NAME.mp4" &
  REC=$!
  sleep 2
  xcrun simctl launch "$UDID" com.riste47.pupitre -tour > "out/$NAME-launch.txt" 2>&1
  sleep 2;  xcrun simctl io "$UDID" screenshot "out/$NAME-1-calendrier.png"
  sleep 4;  xcrun simctl io "$UDID" screenshot "out/$NAME-2-fiche.png"
  sleep 5;  xcrun simctl io "$UDID" screenshot "out/$NAME-3-a-pourvoir.png"
  sleep 6;  xcrun simctl io "$UDID" screenshot "out/$NAME-4-reglages.png"
  sleep 6
  kill -INT $REC; wait $REC 2>/dev/null
  xcrun simctl spawn "$UDID" log show --last 2m --style compact --predicate 'process == "Pupitre"' > "out/$NAME-log.txt" 2>&1 || true
  cp ~/Library/Logs/DiagnosticReports/Pupitre* out/ 2>/dev/null || true
  xcrun simctl shutdown "$UDID" || true
done
ls -la out
