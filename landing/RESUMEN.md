# Landing de Pultec (industrial)

## Qué es
Landing de Pultec industrial: HTML, CSS y JS nativos, sin compilación. Todos los «Probar» y «Entrar» llevan a `https://app.pultec.io/` (hoy detrás de Cloudflare Access). Probar en local: configuración «landing» de `.claude/launch.json` (localhost:8099).

## Estilo
- Tokens en `tokens.css` (claro y oscuro, OKLCH; tinta + morado del logo, Geist) y reglas base en `base.css`; `styles.css` solo la página. Ningún color suelto fuera de los tokens.
- Fondo negro con la cuadrícula gris fina en la portada y el cierre. Cabecera igual que antes.
- Sin animaciones en bucle: los vídeos se reproducen una vez al verse y se quedan en el último fotograma. Con «reducir movimiento» no se reproducen solos y la única aparición (la portada) se muestra ya colocada.

## Secciones
Portada (titular, frase y botones) · escaparate con la app real en un portátil y el móvil del técnico delante · sectores con los iconos de la app · «El problema» (lo disperso → Pultec) · Cómo funciona (7 pasos; en escritorio, vídeo fijo que cambia con el scroll) · Funciones (recortes reales: planificación, carga del equipo, accesos, componentes, criticidad) · Técnicos (dos móviles: orden en marcha e informe) · foto de planta · Planes (mensual/anual) · Preguntas · cierre sin animación.

## Capturas de la app
- `assets/app/*.webp`: pantallas reales de Pultec industrial (`app/tool/vivo.py --industrial`, puerto 8081, `?local=1`), con la simulación «Historial de trabajo» y las órdenes pendientes repartidas entre Ana, Luis y Marta para el lunes 23 de noviembre. Escritorio a 1440x900 @2x; móvil a 390x844 @3x.
- Portada en claro y oscuro (`inicio`, `tec-lista` y sus `-claro`); el resto, solo oscuro.
- Marcos de portátil y móvil hechos con CSS a partir de los tokens `--device-*` y `--alu-*`.

## Vídeos
- Fuente: `video-industrial/` (HyperFrames 0.8.189, 1920x1200). Las escenas de los pasos las genera `python3 tool/escenas.py` desde `tool/escenas.json` (capturas, cámara, cursor, toques y marcos en coordenadas de la app); `intro` y `cierre` están escritas a mano. Render: `npx hyperframes@0.8.189 render -o renders/pultec-industrial.mp4`.
- `assets/video/pultec.mp4` (42,5 s, con efectos) y un corte mudo por paso con su póster: `activos` 2,5–7,05 · `mantenimiento` 7,5–12,55 · `auto` 13–17,55 · `grafo` 18–22,55 · `tecnico` 23–28,55 · `incidencia` 29–34,55 · `parte` 35–39,05 s (1440x900, H.264 CRF 26).
- `assets/video/pulpo-saluda.mp4` ya no se usa.

## Pendiente
- Precios de ejemplo (49 €/39 €) y la etiqueta «Más elegido»: confirmar antes de publicar (`index.html`, `data-price-*`).
- «Contactar» (Empresa) va a la app: falta un correo de contacto.
- Quitar Cloudflare Access de `/industrial/` para que los visitantes puedan entrar.
- Dominio: canonical, og:url, URLs absolutas en og:image, robots.txt y sitemap.xml. Páginas legales.
- El paso 7 muestra el histórico con la descarga del parte; falta una captura del PDF del parte (la descarga no se pudo guardar desde el navegador sin interfaz).
- En la app, las órdenes completadas con fecha pasada cuentan como «Vencidos» en Inicio (con la simulación salían 143): revisar.
