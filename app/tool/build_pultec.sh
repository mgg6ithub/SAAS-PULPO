#!/usr/bin/env bash
# Producción: compila Pultec (industrial) en la raíz para el proyecto `pultec-app` de Cloudflare Pages (app.pultec.io).
# Pages: comando `bash app/tool/build_pultec.sh`, salida `app/build/pultec`, rama `main`.
set -euo pipefail
cd "$(dirname "$0")/.."

# Cloudflare Pages no trae Flutter: se descarga la misma versión que las pruebas de GitHub.
if ! command -v flutter >/dev/null; then
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter pub get
flutter build web --release --dart-define=MARCA=industrial --base-href / --output build/pultec

python3 - <<'PY'
import json, os, re, subprocess
from pathlib import Path

salida = Path('build/pultec')
# Cada versión pide su propio main.dart.js (sin quedarse con el de la caché).
version = os.environ.get('CF_PAGES_COMMIT_SHA') or subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
bootstrap = salida / 'flutter_bootstrap.js'
texto, cambios = re.subn(r'("mainJsPath"\s*:\s*")main\.dart\.js(")',
                        lambda m: m[1] + 'main.dart.js?v=' + version + m[2], bootstrap.read_text(), count=1)
if cambios != 1:
    raise RuntimeError('No se encontró mainJsPath en flutter_bootstrap.js')
bootstrap.write_text(texto)
(salida / 'version.txt').write_text(version + '\n')
indice = salida / 'index.html'
indice.write_text(indice.read_text().replace('<title>Pulcón</title>', '<title>Pultec</title>')
                  .replace('content="Pulcón"', 'content="Pultec"'))
manifiesto = salida / 'manifest.json'
datos = json.loads(manifiesto.read_text())
datos.update(name='Pultec', short_name='Pultec')
manifiesto.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + '\n')
PY
