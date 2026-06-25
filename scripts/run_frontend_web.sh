#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter build web
cd build/web

echo "LightMapz frontend: http://127.0.0.1:8081"
python3 -m http.server 8081 --bind 127.0.0.1
