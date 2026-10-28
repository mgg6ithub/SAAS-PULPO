#!/usr/bin/env bash
# Compila la app Flutter para Cloudflare Pages (que no trae Flutter) y la deja en app/build/web, con la landing
# dentro de /landing. Se pone como «Build command» del proyecto en Cloudflare: bash tool/cloudflare_build.sh
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="${HOME}/flutter"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter config --no-analytics >/dev/null 2>&1 || true

cd "${RAIZ}/app"
flutter pub get
flutter build web --release --base-href /

# Evita la caché antigua: el arranque pide main.dart.js con la versión de este commit.
VERSION="${CF_PAGES_COMMIT_SHA:-$(git -C "${RAIZ}" rev-parse HEAD)}"
python3 - "${VERSION}" <<'PY'
import sys
from pathlib import Path

version = sys.argv[1]
build = Path('build/web')
bootstrap = build / 'flutter_bootstrap.js'
source = bootstrap.read_text()
marker = '"mainJsPath":"main.dart.js"'
if marker not in source:
    raise SystemExit('No se encontró mainJsPath en flutter_bootstrap.js')
bootstrap.write_text(source.replace(marker, f'"mainJsPath":"main.dart.js?v={version}"', 1))
(build / 'version.txt').write_text(version + '\n')
PY

cp -R "${RAIZ}/landing" build/web/landing
echo "Listo: app/build/web (versión ${VERSION})"
