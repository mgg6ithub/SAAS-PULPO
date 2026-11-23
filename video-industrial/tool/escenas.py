#!/usr/bin/env python3
"""Genera las escenas del vídeo de Pultec a partir de capturas reales de la app.

Cada escena: capturas reales (assets/app/*.webp) dentro de una pantalla sobre el fondo
oscuro con cuadrícula de la landing, cámara que se acerca, cursor o toque y marcos que
señalan. Coordenadas en píxeles CSS de la app (escritorio 1440x900, móvil 390x844).

Uso (desde video-industrial/):  python3 tool/escenas.py
"""
import json
import os

W, H = 1920, 1200
# Escritorio: la captura 1440x900 ocupa 1760x1100 centrada
DK, DX, DY = 1760 / 1440, 80, 50
# Móvil: pantalla 480x1040 centrada; barra de estado de 60 px encima de la captura
PW = 480
PK = PW / 390
PSX, PSY = (W - PW) / 2, 80
PBAR = 60

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ESTILO = """
    @font-face { font-family: "Geist"; src: url("assets/fonts/Geist.woff2") format("woff2"); font-weight: 100 900; }
    #root { position: absolute; inset: 0; font-family: "Geist", sans-serif; color: #f3f2f8; overflow: hidden; background: #0d0c13; }
    .grid { position: absolute; inset: 0; background-image: linear-gradient(rgba(243,242,248,.05) 1px, transparent 1px), linear-gradient(90deg, rgba(243,242,248,.05) 1px, transparent 1px); background-size: 64px 64px; background-position: center top;
      -webkit-mask-image: radial-gradient(ellipse 75% 70% at 50% 40%, #000 30%, transparent 80%); mask-image: radial-gradient(ellipse 75% 70% at 50% 40%, #000 30%, transparent 80%); }
    .cam { position: absolute; left: 0; top: 0; width: 1920px; height: 1200px; transform-origin: 0 0; }
    .grupo { position: absolute; inset: 0; }
    .pantalla { position: absolute; left: 80px; top: 50px; width: 1760px; height: 1100px; border-radius: 18px; overflow: hidden; background: #121119; box-shadow: 0 0 0 1px #2c2a39; }
    .pantalla img, .movil__pantalla img.cap { position: absolute; left: 0; top: 0; width: 100%; }
    .movil { position: absolute; left: %PL%px; top: %PT%px; width: %PFW%px; height: %PFH%px; border-radius: 74px; background: #1a1a1d; box-shadow: inset 0 0 0 2px #45454b, inset 0 0 0 5px #0b0b0d, 0 50px 90px -40px #000; }
    .movil__pantalla { position: absolute; left: 14px; top: 14px; width: 480px; height: 1040px; border-radius: 60px; overflow: hidden; background: #121119; }
    .movil__pantalla img.cap { top: 60px; }
    .movil__isla { position: absolute; z-index: 3; left: 165px; top: 16px; width: 150px; height: 40px; border-radius: 20px; background: #000; }
    .movil__barra { position: absolute; z-index: 2; left: 0; right: 0; top: 0; height: 60px; display: flex; align-items: center; justify-content: space-between; padding: 0 44px 0 58px; font-size: 31px; font-weight: 600; color: #f3f2f8; background: #121119; }
    .movil__barra svg { width: 92px; fill: #f3f2f8; stroke: #f3f2f8; }
    .marco { position: absolute; border: 3px solid #8b5cf6; border-radius: 14px; box-shadow: 0 0 0 6px rgba(139,92,246,.18); }
    .cursor { position: absolute; left: 0; top: 0; width: 34px; height: 50px; }
    .toque { position: absolute; left: -32px; top: -32px; width: 64px; height: 64px; border-radius: 50%; background: rgba(243,242,248,.28); border: 2px solid rgba(243,242,248,.85); }
    .onda { position: absolute; left: -40px; top: -40px; width: 80px; height: 80px; border-radius: 50%; border: 3px solid #8b5cf6; opacity: 0; }
"""
ESTILO = (ESTILO.replace("%PL%", str(PSX - 14)).replace("%PT%", str(PSY - 14))
          .replace("%PFW%", str(PW + 28)).replace("%PFH%", str(1040 + 28)))

BARRA = ('<div class="movil__barra"><span>9:41</span><svg viewBox="0 0 64 14"><path d="M1 10h3v3H1zM6 8h3v5H6zM11 5h3v8h-3zM16 2h3v11h-3z"/>'
         '<path d="M30 5.2a9 9 0 0 1 12 0M32.4 7.6a5.6 5.6 0 0 1 7.2 0M34.8 10a2.2 2.2 0 0 1 2.4 0" fill="none" stroke-width="1.6" stroke-linecap="round"/>'
         '<rect x="45.5" y="2.5" width="15" height="9" rx="2.5" fill="none"/><rect x="47.5" y="4.5" width="10" height="5" rx="1"/></svg></div>')
FLECHA = ('<svg class="cursor" id="{id}" viewBox="0 0 34 50"><path d="M3 3 L3 40 L12 32 L18 47 L25 44 L19 30 L31 30 Z" '
          'fill="#ffffff" stroke="#0d0c13" stroke-width="2.4" stroke-linejoin="round"/></svg>')


def punto(grupo, x, y):
    """Coordenadas de la app a coordenadas del vídeo."""
    if grupo == "movil":
        return PSX + x * PK, PSY + PBAR + y * PK
    return DX + x * DK, DY + y * DK


def camara(grupo, s, x, y):
    """Transformación de la cámara para centrar (x, y) de la app a escala s."""
    if s == 1:
        return 0, 0
    px, py = punto(grupo, x, y)
    tx = min(0, max(W - W * s, W / 2 - px * s))
    ty = min(0, max(H - H * s, H / 2 - py * s))
    return round(tx, 1), round(ty, 1)


def escena(e):
    i = e["id"]
    html, js = [], []
    html.append('<div class="grid"></div>')
    html.append(f'<div class="cam" id="{i}-cam" data-layout-allow-overflow data-layout-allow-overlap>')
    for g in ("escritorio", "movil"):
        caps = [c for c in e["caps"] if c.get("g", "escritorio") == g]
        if not caps:
            continue
        oculto = '' if g == e.get("empieza", sorted({c.get("g", "escritorio") for c in e["caps"]})[0]) else ' style="opacity:0"'
        html.append(f'<div class="grupo" id="{i}-{g}"{oculto}>')
        if g == "escritorio":
            html.append('<div class="pantalla">')
        else:
            html.append('<div class="movil"><div class="movil__pantalla">' + BARRA + '<div class="movil__isla"></div>')
        for k, c in enumerate(caps):
            oculto = ' style="opacity:0"' if k else ''
            html.append(f'<img class="cap" id="{i}-{c["n"]}" src="assets/app/{c["src"]}.webp" alt=""{oculto} />')
        html.append('</div>' if g == "escritorio" else '</div></div>')
        for k, m in enumerate(e.get("marcos", [])):
            if m.get("g", "escritorio") != g:
                continue
            x, y = punto(g, m["x"], m["y"])
            k2 = (PK if g == "movil" else DK)
            html.append(f'<div class="marco" id="{i}-m{k}" style="opacity:0;left:{x - 8:.0f}px;top:{y - 8:.0f}px;width:{m["w"] * k2 + 16:.0f}px;height:{m["h"] * k2 + 16:.0f}px"></div>')
        if g == "escritorio":
            html.append(FLECHA.format(id=f"{i}-cur"))
        else:
            html.append(f'<div class="cursor" id="{i}-toq" style="opacity:0"><div class="toque"></div></div>')
        html.append(f'<div class="cursor" id="{i}-{g}-onda"><div class="onda"></div></div>')
        html.append('</div>')
    html.append('</div>')

    html_sin_cursor = []
    js.append('const tl = gsap.timeline({ paused: true });')
    # Grupos: quién se ve al principio y cambios
    grupos = sorted({c.get("g", "escritorio") for c in e["caps"]})
    inicio = e.get("empieza", grupos[0])
    for t, g in e.get("cambia", []):
        otro = [x for x in grupos if x != g][0]
        js.append(f'tl.to("#{i}-{otro}", {{ opacity: 0, scale: 0.97, transformOrigin: "50% 50%", duration: 0.45, ease: "power2.in" }}, {t});')
        js.append(f'tl.fromTo("#{i}-{g}", {{ opacity: 0, scale: 1.03, transformOrigin: "50% 50%" }}, {{ opacity: 1, scale: 1, duration: 0.55, ease: "power3.out" }}, {t + 0.3});')
    # Capturas: la primera de cada grupo visible; las demás entran con fundido
    vistos = set()
    for c in e["caps"]:
        g = c.get("g", "escritorio")
        if g not in vistos:
            vistos.add(g)
        else:
            js.append(f'tl.to("#{i}-{c["n"]}", {{ opacity: 1, duration: 0.35, ease: "power2.out" }}, {c["t"]});')
    # Entrada suave del conjunto
    js.append(f'tl.fromTo("#{i}-cam", {{ opacity: 0 }}, {{ opacity: 1, duration: 0.35, ease: "power2.out" }}, 0);')
    # Cámara
    g0 = inicio
    js.append(f'tl.set("#{i}-cam", {{ x: 0, y: 0, scale: 1 }}, 0);')
    for c in e.get("cam", []):
        g = c.get("g", g0)
        tx, ty = camara(g, c["s"], c.get("x", 0), c.get("y", 0))
        js.append(f'tl.to("#{i}-cam", {{ x: {tx}, y: {ty}, scale: {c["s"]}, duration: {c.get("d", 1.1)}, ease: "power3.inOut" }}, {c["t"]});')
    # Cursor (escritorio) y toques (móvil)
    for g, cid in (("escritorio", f"{i}-cur"), ("movil", f"{i}-toq")):
        pasos = [p for p in e.get("cursor", []) if p.get("g", "escritorio") == g]
        if g not in grupos:
            continue
        if not pasos:
            html_sin_cursor.append(cid)
            continue
        x0, y0 = punto(g, *pasos[0]["desde"]) if "desde" in pasos[0] else (W * 0.8, H * 1.05)
        js.append(f'tl.set("#{cid}", {{ x: {x0:.0f}, y: {y0:.0f} }}, 0);')
        for p in pasos:
            x, y = punto(g, p["x"], p["y"])
            if g == "movil":
                js.append(f'tl.set("#{cid}", {{ x: {x:.0f}, y: {y:.0f} }}, {p["t"]});')
                js.append(f'tl.fromTo("#{cid}", {{ opacity: 0, scale: 1.4 }}, {{ opacity: 1, scale: 1, duration: 0.18, ease: "power2.out" }}, {p["t"]});')
                js.append(f'tl.to("#{cid}", {{ opacity: 0, duration: 0.25, ease: "power2.in" }}, {p["t"] + 0.32});')
            else:
                js.append(f'tl.to("#{cid}", {{ x: {x:.0f}, y: {y:.0f}, duration: {p.get("d", 0.7)}, ease: "power2.inOut" }}, {p["t"]});')
            if p.get("clic"):
                tc = p["t"] + (0 if g == "movil" else p.get("d", 0.7))
                if g == "escritorio":
                    js.append(f'tl.to("#{cid}", {{ scale: 0.86, duration: 0.08, yoyo: true, repeat: 1, ease: "power2.out", transformOrigin: "3px 3px" }}, {tc});')
                oid = f"#{i}-{g}-onda"
                js.append(f'tl.set("{oid}", {{ x: {x:.0f}, y: {y:.0f} }}, {tc});')
                js.append(f'tl.fromTo("{oid} .onda", {{ opacity: 0.9, scale: 0.4 }}, {{ opacity: 0, scale: 1.6, duration: 0.5, ease: "power2.out" }}, {tc});')
    # Marcos
    for k, m in enumerate(e.get("marcos", [])):
        js.append(f'tl.fromTo("#{i}-m{k}", {{ opacity: 0, scale: 1.04 }}, {{ opacity: 1, scale: 1, duration: 0.35, ease: "power3.out" }}, {m["t"]});')
        if "hasta" in m:
            js.append(f'tl.to("#{i}-m{k}", {{ opacity: 0, duration: 0.3, ease: "power2.in" }}, {m["hasta"]});')
    # Salida
    js.append(f'tl.to("#{i}-cam", {{ opacity: 0, duration: 0.35, ease: "power2.in" }}, {e["dur"] - 0.4});')
    js.append(f'window.__timelines["{i}"] = tl;')

    cuerpo = "\n    ".join(html)
    for cid in html_sin_cursor:
        cuerpo = cuerpo.replace(f'id="{cid}"', f'id="{cid}" style="display:none"')
    return (f'<template>\n  <style>{ESTILO}  </style>\n'
            f'  <div id="root" data-composition-id="{i}" data-width="{W}" data-height="{H}">\n    '
            + cuerpo + '\n  </div>\n  <script>\n    ' + "\n    ".join(js) + '\n  </script>\n</template>\n')


ESCENAS = json.load(open(os.path.join(AQUI, "tool", "escenas.json"), encoding="utf-8"))

if __name__ == "__main__":
    for e in ESCENAS:
        with open(os.path.join(AQUI, "compositions", e["id"] + ".html"), "w", encoding="utf-8") as f:
            f.write(escena(e))
        print("escena", e["id"], e["dur"], "s")
