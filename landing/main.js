// Pultec · landing. Sin dependencias: tema claro/oscuro, aparición al hacer scroll, pasos con vídeo fijo,
// líneas del bloque «El problema», vídeos que solo se reproducen a la vista y panel que sigue al ratón.
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
  document.querySelectorAll(".reveal, .tile, .flow").forEach((el) => io.observe(el));

  // Vídeos: carga perezosa y solo se reproducen mientras se ven
  const reproducir = (v) => { const p = v.play(); if (p) p.catch(() => {}); };
  const vio = new IntersectionObserver((es) => es.forEach(({ target: v, isIntersecting }) => {
    if (isIntersecting) { if (v.dataset.src && !v.src) v.src = v.dataset.src; if (!quieto) reproducir(v); }
    else if (!v.paused) v.pause();
  }), { threshold: 0.25 });
  document.querySelectorAll("video.autoplay, .step__video").forEach((v) => vio.observe(v));

  // Cómo funciona: el paso centrado cambia el vídeo grande (fundido entre dos <video>)
  const pasos = [...document.querySelectorAll(".step")];
  const capas = [...document.querySelectorAll(".stage__video")];
  const barra = document.getElementById("progreso");
  let actual = 0, capa = 0;
  const activar = (i) => {
    if (i === actual || i < 0) return;
    actual = i;
    pasos.forEach((p, j) => p.classList.toggle("is-active", j === i));
    if (barra) barra.style.width = ((i + 1) / pasos.length) * 100 + "%";
    const sig = capas[1 - capa], viejo = capas[capa];
    sig.src = pasos[i].dataset.video;
    sig.poster = pasos[i].dataset.poster;
    if (!quieto) reproducir(sig);
    sig.classList.add("is-on");
    viejo.classList.remove("is-on");
    setTimeout(() => viejo.pause(), 480);
    capa = 1 - capa;
  };
  if (capas.length) {
    if (barra) barra.style.width = 100 / pasos.length + "%";
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
  flujo?.addEventListener("transitionend", dibujar);

  // Panel de la portada: se inclina un poco siguiendo el ratón
  const panel = document.getElementById("panel");
  if (panel && !quieto && matchMedia("(hover: hover)").matches) {
    const zona = panel.parentElement;
    zona.addEventListener("mousemove", (e) => {
      const r = zona.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5;
      panel.style.transform = `rotateX(${(-y * 5).toFixed(2)}deg) rotateY(${(x * 6).toFixed(2)}deg)`;
    });
    zona.addEventListener("mouseleave", () => { panel.style.transform = ""; });
  }

  // Detalles: la luz de cada tarjeta sigue al ratón
  document.querySelectorAll(".tile").forEach((tile) => tile.addEventListener("mousemove", (e) => {
    const r = tile.getBoundingClientRect();
    tile.style.setProperty("--mx", e.clientX - r.left + "px");
    tile.style.setProperty("--my", e.clientY - r.top + "px");
  }));

  // Facturación mensual / anual
  document.querySelectorAll("[data-billing]").forEach((b) => b.addEventListener("click", () => {
    const k = b.dataset.billing === "mes" ? "Mes" : "Anio";
    document.querySelectorAll("[data-billing]").forEach((x) => x.classList.toggle("is-on", x === b));
    document.querySelectorAll("[data-price-mes]").forEach((p) => { p.textContent = p.dataset["price" + k]; });
    document.querySelectorAll("[data-per-mes]").forEach((p) => { p.textContent = p.dataset["per" + k]; });
  }));

  // Paralaje suave de la foto
  const foto = document.querySelector(".photo__img");
  if (foto && !quieto) {
    const mover = () => {
      const r = foto.parentElement.getBoundingClientRect();
      if (r.bottom < 0 || r.top > innerHeight) return;
      foto.style.transform = `translateY(${((r.top + r.height / 2 - innerHeight / 2) / innerHeight) * -50}px)`;
    };
    addEventListener("scroll", mover, { passive: true });
    mover();
  }
})();
