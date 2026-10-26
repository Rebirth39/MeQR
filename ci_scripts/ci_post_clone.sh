#!/bin/sh
# Xcode Cloud runs this after cloning. Keep TestFlight build numbers unique and
# above the local 1.8.0 build (31): first cloud build becomes 32, then 33, ...
set -e
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  cd "${CI_PRIMARY_REPOSITORY_PATH:?}"
  xcrun agvtool new-version -all "$((31 + CI_BUILD_NUMBER))"
fi
