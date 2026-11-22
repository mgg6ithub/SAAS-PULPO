# Landing de Pultec (industrial)

## Qué es
Landing de Pultec industrial: HTML, CSS y JS nativos, sin compilación. Todos los «Probar» y «Entrar» llevan a `https://saas-pulpo.pages.dev/industrial/` (hoy detrás de Cloudflare Access).

## Secciones
Portada con el vídeo completo (sonido opcional) · sectores con los iconos reales de la app · «Hoy / Con Pultec» · Cómo funciona (5 pasos; en escritorio, un vídeo fijo que cambia con el scroll) · Funciones (8 tarjetas con demos en vivo) · Técnicos · foto de planta · Planes (Básico gratis, Premium, Empresa; mensual/anual) · Preguntas · cierre con el pulpo saludando.

## Vídeos
- Fuente: `video-industrial/` (HyperFrames, mismo estilo que el clip de muestra del vídeo de Pulpo). Render: `npx hyperframes@0.8.189 render -o renders/pultec-industrial.mp4`.
- `assets/video/pultec.mp4` (34 s, con efectos de sonido) y un corte mudo por paso (`auto`, `asignar`, `tecnico`, `incidencia`, `parte`), con su póster `.jpg`. Cortes con ffmpeg: 3.5–10.5, 10.5–15.5, 15.5–22, 22–27, 27–31 s.
- Solo se reproducen mientras se ven; con «reducir movimiento» no se reproducen solos.

## Pendiente
- Precios de ejemplo (49 €/39 €): decidir los reales en `index.html` (`data-price-*`).
- «Contactar» (Empresa) va a la app: falta un correo de contacto.
- Quitar Cloudflare Access de `/industrial/` para que los visitantes puedan entrar.
- Dominio: canonical, og:url, URLs absolutas en og:image, robots.txt y sitemap.xml. Páginas legales.
