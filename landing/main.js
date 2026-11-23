// Pultec · landing. Sin dependencias: tema claro/oscuro, una aparición en la portada, pasos con vídeo fijo,
// líneas del bloque «El problema» y vídeos que se reproducen una vez, solo a la vista (nada en bucle).
(() => {
  const root = document.documentElement;
  root.classList.add("js");
  const quieto = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Tema: el botón alterna y se recuerda en este navegador
  const oscuroSistema = matchMedia("(prefers-color-scheme: dark)");
  const temaActual = () => root.dataset.theme || (oscuroSistema.matches ? "dark" : "light");
  document.getElementById("tema")?.addEventListener("click", () => {
    const nuevo = temaActual() === "dark" ? "light" : "dark";
    root.dataset.theme = nuevo;
    try { localStorage.setItem("pultec-tema", nuevo); } catch (e) {}
  });

  // Barra con borde al bajar
  const nav = document.getElementById("nav");
  const onScroll = () => nav.classList.toggle("is-scrolled", scrollY > 8);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Aparición (una vez)
  const io = new IntersectionObserver((es) => es.forEach((e) => {
    if (e.isIntersecting) { e.target.classList.add("is-in"); io.unobserve(e.target); }
  }), { rootMargin: "0px 0px -8% 0px", threshold: 0.15 });
  document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

  // Vídeos: carga perezosa y solo se reproducen mientras se ven
  const reproducir = (v) => { const p = v.play(); if (p) p.catch(() => {}); };
  const vio = new IntersectionObserver((es) => es.forEach(({ target: v, isIntersecting }) => {
    if (isIntersecting) { if (v.dataset.src && !v.src) v.src = v.dataset.src; if (!quieto) reproducir(v); }
    else if (!v.paused) v.pause();
  }), { threshold: 0.25 });
  document.querySelectorAll(".step__video").forEach((v) => vio.observe(v));

  // Cómo funciona: el paso centrado cambia el vídeo grande (fundido entre dos <video>)
  const pasos = [...document.querySelectorAll(".step")];
  const capas = [...document.querySelectorAll(".stage__video")];
  const barra = document.getElementById("progreso");
  let actual = 0, capa = 0;
  const activar = (i) => {
    if (i === actual || i < 0) return;
    actual = i;
    pasos.forEach((p, j) => p.classList.toggle("is-active", j === i));
    if (barra) barra.style.transform = `scaleX(${(i + 1) / pasos.length})`;
    const sig = capas[1 - capa], viejo = capas[capa];
    sig.src = pasos[i].dataset.video;
    sig.poster = pasos[i].dataset.poster;
    sig.currentTime = 0;
    if (!quieto) reproducir(sig);
    sig.classList.add("is-on");
    viejo.classList.remove("is-on");
    setTimeout(() => viejo.pause(), 480);
    capa = 1 - capa;
  };
  if (capas.length) {
    if (barra) barra.style.transform = `scaleX(${1 / pasos.length})`;
    const pio = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) activar(pasos.indexOf(e.target)); }), { rootMargin: "-45% 0px -45% 0px" });
    pasos.forEach((p) => pio.observe(p));
    new IntersectionObserver(([e]) => { const v = capas[capa]; if (e.isIntersecting && !quieto) reproducir(v); else v.pause(); }, { threshold: 0.1 })
      .observe(document.querySelector(".story__stage"));
  }

  // El problema: líneas discontinuas de cada carta a Pultec y de Pultec a cada resultado
  const flujo = document.getElementById("flujo");
  const lineas = flujo?.querySelector(".flow__lines");
  const dibujar = () => {
    if (!flujo || getComputedStyle(lineas).display === "none") return;
    const f = flujo.getBoundingClientRect();
    const c = flujo.querySelector(".flow__core").getBoundingClientRect();
    const cx = c.left - f.left, cy = c.top - f.top + c.height / 2, cr = cx + c.width;
    let d = "";
    flujo.querySelectorAll(".mess").forEach((m) => {
      const r = m.getBoundingClientRect(), x = r.right - f.left, y = r.top - f.top + r.height / 2, k = (cx - x) / 2;
      d += `<path d="M${x} ${y} C${x + k} ${y} ${cx - k} ${cy} ${cx} ${cy}"/>`;
    });
    flujo.querySelectorAll(".flow__out li").forEach((o) => {
      const r = o.getBoundingClientRect(), x = r.left - f.left, y = r.top - f.top + r.height / 2, k = (x - cr) / 2;
      d += `<path class="out" d="M${cr} ${cy} C${cr + k} ${cy} ${x - k} ${y} ${x} ${y}"/>`;
    });
    lineas.innerHTML = d;
  };
  dibujar();
  addEventListener("resize", dibujar);
  document.fonts?.ready.then(dibujar);

  // Facturación mensual / anual
  document.querySelectorAll("[data-billing]").forEach((b) => b.addEventListener("click", () => {
    const k = b.dataset.billing === "mes" ? "Mes" : "Anio";
    document.querySelectorAll("[data-billing]").forEach((x) => x.classList.toggle("is-on", x === b));
    document.querySelectorAll("[data-price-mes]").forEach((p) => { p.textContent = p.dataset["price" + k]; });
    document.querySelectorAll("[data-per-mes]").forEach((p) => { p.textContent = p.dataset["per" + k]; });
  }));

})();
