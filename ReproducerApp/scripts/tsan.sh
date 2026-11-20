#!/usr/bin/env bash
set -euo pipefail

UDID=${1:?usage: scripts/tsan.sh <simulator udid> [seconds to run]}
RUN_SECONDS=${2:-60}
APP_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPORT_DIR="$APP_DIR/tsan-reports"
DERIVED_DATA="$APP_DIR/ios/build"
BUNDLE_ID=org.reactjs.native.example.ReproducerApp

main() {
  if [ -z "${SKIP_BUILD:-}" ]; then
    build
  fi
  run
  symbolize
  print_summaries
}

build() {
  cd "$APP_DIR/ios"
  bundle install
  RCT_USE_PREBUILT_RNCORE=0 RCT_USE_RN_DEP=0 LANG=en_US.UTF-8 bundle exec pod install
  xcodebuild \
    -workspace ReproducerApp.xcworkspace \
    -scheme ReproducerApp \
    -configuration Release \
    -sdk iphonesimulator \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    -enableThreadSanitizer YES \
    ENABLE_THREAD_SANITIZER=YES \
    DEBUG_INFORMATION_FORMAT=dwarf \
    build
}

run() {
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID"
  xcrun simctl install "$UDID" "$(app_path)"
  rm -rf "$REPORT_DIR"
  mkdir -p "$REPORT_DIR"
  SIMCTL_CHILD_TSAN_OPTIONS="log_path=$REPORT_DIR/tsan halt_on_error=0" \
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID"
  sleep "$RUN_SECONDS"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
}

symbolize() {
  local binary report addresses address location
  binary="$(app_path)/ReproducerApp"
  for report in "$REPORT_DIR"/tsan.*; do
    [ -e "$report" ] || continue
    addresses=$(grep -oE 'ReproducerApp:arm64\+0x[0-9a-f]+' "$report" | sed 's/.*+//' | sort -u)
    [ -n "$addresses" ] || continue
    while IFS=$'\t' read -r address location; do
      [ -n "$location" ] || continue
      ADDRESS=$address LOCATION=$location perl -pi -e \
        's/(<null> )?\(ReproducerApp:arm64\+\Q$ENV{ADDRESS}\E\)/$ENV{LOCATION} (ReproducerApp:arm64+$ENV{ADDRESS})/g' "$report"
    done < <(paste <(echo "$addresses") <(atos -o "$binary" -arch arm64 $addresses | awk '{ print match($0, /\([^()]+:[0-9]+\)$/) ? substr($0, RSTART + 1, RLENGTH - 2) : "" }'))
  done
}

app_path() {
  find "$DERIVED_DATA" -maxdepth 4 -path '*/Release-iphonesimulator/ReproducerApp.app'
}

print_summaries() {
  echo "ThreadSanitizer reports in $REPORT_DIR:"
  grep -h '^SUMMARY:' "$REPORT_DIR"/tsan.* 2>/dev/null | sort | uniq -c || echo "  none"
}

main
