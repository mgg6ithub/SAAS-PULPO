#!/usr/bin/env bash
# Publica Pultec en / e iPultec en /industrial/ con la misma versión del repositorio.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
flutter build web --release --base-href / --output build/pages-residencial
flutter build web --release --dart-define=MARCA=industrial --base-href /industrial/ --output build/pages-industrial

python3 - <<'PY'
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

salida = Path('build/pages')
if salida.exists():
    shutil.rmtree(salida)
shutil.copytree('build/pages-residencial', salida)
shutil.copytree('build/pages-industrial', salida / 'industrial')
shutil.copytree('../landing', salida / 'landing')
version = os.environ.get('CF_PAGES_COMMIT_SHA') or subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
for carpeta in [salida, salida / 'industrial']:
    bootstrap = carpeta / 'flutter_bootstrap.js'
    texto, cambios = re.subn(r'("mainJsPath"\s*:\s*")main\.dart\.js(")',
                            lambda m: m[1] + 'main.dart.js?v=' + version + m[2], bootstrap.read_text(), count=1)
    if cambios != 1:
        raise RuntimeError('No se encontró mainJsPath en flutter_bootstrap.js')
    bootstrap.write_text(texto)
    (carpeta / 'version.txt').write_text(version + '\n')
indice = salida / 'industrial/index.html'
indice.write_text(indice.read_text().replace('<title>Pulpo</title>', '<title>iPultec</title>')
                  .replace('content="Pulpo"', 'content="iPultec"'))
manifiesto = salida / 'industrial/manifest.json'
datos = json.loads(manifiesto.read_text())
datos.update(name='iPultec', short_name='iPultec')
manifiesto.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + '\n')
PY
