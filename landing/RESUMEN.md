# Landing de Pulpo

## Dirección
- Estilo: minimalista con acento de producto moderno. Elegido por el agente con autorización del usuario.
- Carácter: claro, preciso, con chispa.
- Referencias: edens-2 (hero centrado, un solo botón oscuro, producto enmarcado con halo suave) y sendr (esquema del flujo de automatización). Solo se ha tomado la composición; no hay textos ni recursos de esas páginas.
- Paleta: tinta #14121F, morado de marca #6A2FF6 (tomado del icono), morado suave #EFE9FF, fondo #F7F6FB y verde azulado #0F9F8F para la segunda ruta.
- Tipografía: Geist (Google Fonts, licencia OFL).
- Movimiento: suave y solo con CSS. Se pulsa "Organizar", se asignan las tareas y se dibujan las rutas. Se desactiva si el sistema pide reducir el movimiento.
- Tecnología: HTML y CSS nativos, sin JavaScript ni compilación.

## Contenido
Se centra en el núcleo: tareas, equipo, botón "Organizar" y rutas optimizadas, más historial y aprendizaje con IA. El módulo de finanzas aparece solo como "Próximamente". El mapa del hero es una ilustración, no una captura real; los nombres y las direcciones son de ejemplo. No hay cifras, testimonios ni precios.

## Botón principal
"Probar Pulpo" (navegación, hero y bloque final) lleva a `../`, la app publicada en la raíz de GitHub Pages (/SAAS-PULPO/).

## Recursos
- `assets/pulpo.png`: el icono del usuario, limpio de manchas y recortado.
- `assets/favicon.png`, `assets/apple-touch-icon.png` y `assets/og.png`: generados a partir del icono.

## Verificaciones
- Capturas revisadas (no guardadas): escritorio a 1440 px y móvil a 390 px. No se ven desbordamientos ni recortes.
- Accesibilidad: enlace para saltar al contenido, foco visible, la ilustración se describe con aria-label y el movimiento se reduce si el sistema lo pide.

## Pendiente
- Dominio: después hay que añadir canonical, og:url, URLs absolutas en og:image, robots.txt y sitemap.xml.
- og.png solo lleva el icono. Se puede hacer una versión con texto.
- Páginas legales o de contacto, si se publican.
