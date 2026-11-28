#!/bin/zsh
# Compila Pultec iOS, la instala en el simulador y la abre con una cuenta de prueba local.
#   ./probar.sh            → oficina (admin@pultec.local)
#   ./probar.sh tecnico    → técnico (tecnico@pultec.local)
#   ./probar.sh como Ana   → oficina viendo la app como el técnico «Ana»
#   SIM="iPad Pro 13-inch (M5)" ./probar.sh
# Necesita la Supabase local arrancada (../entorno.sh arrancar).
set -e
cd "$(dirname "$0")"
SIM="${SIM:-iPhone 17}"
DD="${DD:-${TMPDIR:-/tmp}/pultec-ios-dd}"
CUENTA="admin@pultec.local:pultec1234"
[ "$1" = "tecnico" ] && CUENTA="tecnico@pultec.local:pultec1234"

xcodebuild -project Pultec.xcodeproj -scheme Pultec -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath "$DD" build -quiet 2>&1 | grep -E "^/.*error:" && exit 1
UDID=$(xcrun simctl list devices available | grep "$SIM (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl terminate "$UDID" com.pultec.app 2>/dev/null || true
xcrun simctl install "$UDID" "$DD/Build/Products/Debug-iphonesimulator/Pultec.app"
[ "$1" = "como" ] && export SIMCTL_CHILD_PULTEC_COMO="$2"
SIMCTL_CHILD_PULTEC_ENTRAR="$CUENTA" xcrun simctl launch "$UDID" com.pultec.app
