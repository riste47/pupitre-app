#!/bin/bash
# Démarre un iPhone puis un iPad simulés, installe Pupitre, le lance en mode « visite » (-tour) et filme ~20 s.
set -u
APP=$(find build/Build/Products -name "Pupitre.app" -type d | head -1)
mkdir -p out
pick() { # le runtime iOS le plus récent ; de préférence un modèle « Pro » (iPhone) ou « Pro 11 » (iPad)
  xcrun simctl list devices available -j | jq -r --arg k "$1" '.devices | to_entries | map(select(.key|test("iOS"))) | sort_by(.key|capture("iOS-(?<a>[0-9]+)-(?<b>[0-9]+)")|[(.a|tonumber),(.b|tonumber)]) | last | .value | (map(select(.name|startswith($k)) | select(.name|test("Pro"))) + map(select(.name|startswith($k)))) | .[0].udid // empty'
}
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
  DOCS="$(xcrun simctl get_app_container "$UDID" com.riste47.pupitre data)/Documents"
  N=1
  for SHOT in 1-calendrier 2-fiche 3-a-pourvoir 4-reglages; do   # l'app signale chaque écran prêt (step-N)
    for i in $(seq 1 120); do [ -f "$DOCS/step-$N" ] && break; sleep 0.25; done
    [ -f "$DOCS/step-$N" ] || echo "⚠︎ $KIND : écran $N non signalé (capture quand même)"
    xcrun simctl io "$UDID" screenshot "out/$NAME-$SHOT.png"
    touch "$DOCS/shot-$N"
    N=$((N+1))
  done
  sleep 3
  kill -INT $REC; wait $REC 2>/dev/null
  xcrun simctl spawn "$UDID" log show --last 2m --style compact --predicate 'process == "Pupitre"' > "out/$NAME-log.txt" 2>&1 || true
  cp ~/Library/Logs/DiagnosticReports/Pupitre* out/ 2>/dev/null || true
  xcrun simctl shutdown "$UDID" || true
done
ls -la out
