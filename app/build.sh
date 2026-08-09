#!/usr/bin/env bash
# Cloud build for the Flutter web app (used by Vercel). Installs the Flutter
# SDK, generates the web runner, and builds a release bundle to build/web.
set -euo pipefail

if [ -d flutter ]; then
  (cd flutter && git pull --ff-only)
else
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable
fi

export PATH="$PWD/flutter/bin:$PATH"

flutter --version
flutter config --enable-web
flutter create . --platforms=web
flutter build web --release
