#!/usr/bin/env bash
# Crea en Stripe lo que necesita Pultec para cobrar: el producto Premium, sus dos precios y el IVA.
# Se puede repetir sin duplicar nada (busca por id / lookup_key / metadata antes de crear).
# Sirve igual para el modo prueba y el real: las funciones buscan los precios por lookup_key, no por id.
#
#   supabase/stripe/preparar.sh            usa STRIPE_SECRET_KEY de supabase/.env (o del entorno)
#
# Precios sin IVA (tax_behavior=exclusive); el IVA del 21 % se suma en el pago.
set -euo pipefail
cd "$(dirname "$0")/.."

K="${STRIPE_SECRET_KEY:-$(grep -s '^STRIPE_SECRET_KEY=' .env | cut -d= -f2- | tr -d '\r" ')}"
case "$K" in
  sk_test_*|rk_test_*) echo "Stripe en modo PRUEBA" ;;
  sk_live_*|rk_live_*) read -rp "⚠  Clave REAL: se crearán productos en el modo real. Escribe «si» para seguir: " r; [ "$r" = si ] || exit 1 ;;
  *) echo "Falta STRIPE_SECRET_KEY (en supabase/.env o en el entorno)." >&2; exit 1 ;;
esac

api() { curl -sS -u "$K:" "https://api.stripe.com/v1/$1" "${@:2}"; }
campo() { python3 -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

# 1. Producto (id fijo: así se encuentra siempre)
if api products/pultec_premium | campo "'error' in d" | grep -q True; then
  api products -d id=pultec_premium -d name="Pultec Premium" \
    -d description="Activos ilimitados, hasta 15 técnicos, incidencias con fotos, avisos y mantenimiento por horas." \
    -d tax_code=txcd_10103001 -d "metadata[app]=pultec" >/dev/null
  echo "✓ Producto creado: pultec_premium"
else
  echo "· Producto ya existe: pultec_premium"
fi

# 2. Precios (lookup_key fijo). Importe en céntimos.
precio() { # lookup_key importe intervalo nombre
  local hay
  hay=$(api "prices?lookup_keys[]=$1&active=true" | campo "len(d.get('data', []))")
  if [ "$hay" = 0 ]; then
    api prices -d product=pultec_premium -d currency=eur -d unit_amount="$2" \
      -d "recurring[interval]=$3" -d tax_behavior=exclusive -d lookup_key="$1" -d nickname="$4" >/dev/null
    echo "✓ Precio creado: $1"
  else
    echo "· Precio ya existe: $1"
  fi
}
precio pultec_premium_mensual 4900 month "Premium mensual (49 €/mes)"
precio pultec_premium_anual 46800 year "Premium anual (39 €/mes = 468 €/año)"

# 3. IVA 21 % (no admite id propio: se marca con metadata[clave]=pultec_iva21)
iva=$(api "tax_rates?active=true&limit=100" | campo "next((t['id'] for t in d.get('data', []) if t.get('metadata', {}).get('clave') == 'pultec_iva21'), '')")
if [ -z "$iva" ]; then
  api tax_rates -d display_name=IVA -d percentage=21 -d inclusive=false -d country=ES \
    -d jurisdiction=ES -d tax_type=vat -d "metadata[clave]=pultec_iva21" >/dev/null
  echo "✓ IVA 21 % creado"
else
  echo "· IVA 21 % ya existe"
fi

echo "Listo."
