// Pultec · landing. Sin dependencias: tema claro/oscuro, aparición al hacer scroll, pasos con vídeo fijo,
// líneas del bloque «El problema», vídeos que solo se reproducen a la vista y demos que se animan una vez.
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
  document.querySelectorAll("video.autoplay, .step__video, #film").forEach((v) => vio.observe(v));

  // Sonido del vídeo principal
  const film = document.getElementById("film");
  const sonido = document.getElementById("sonido");
  sonido?.addEventListener("click", () => {
    film.muted = !film.muted;
    if (!film.muted) { film.currentTime = 0; reproducir(film); }
    sonido.setAttribute("aria-pressed", String(!film.muted));
    sonido.querySelector("span").textContent = film.muted ? "Activar sonido" : "Silenciar";
  });

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

  // Demos de las tarjetas: se animan una vez al aparecer
  const unaVez = (sel, fn) => {
    const el = document.querySelector(sel); if (!el) return;
    new IntersectionObserver(([e], o) => { if (e.isIntersecting) { o.disconnect(); fn(el); } }, { threshold: 0.5 }).observe(el);
  };
  const contar = (de, a, ms, pinta) => {
    if (quieto) return pinta(a);
    const t0 = performance.now();
    const paso = (t) => { const p = Math.min(1, (t - t0) / ms), e = 1 - Math.pow(1 - p, 3); pinta(de + (a - de) * e); if (p < 1) requestAnimationFrame(paso); };
    requestAnimationFrame(paso);
  };
  unaVez(".ringdemo", (el) => {
    const f = el.querySelector(".rf"), d = el.querySelector("[data-ring-days]");
    f.style.strokeDashoffset = "90"; f.style.stroke = "var(--amber)";
    setTimeout(() => { f.style.stroke = "var(--red)"; }, 1300);
    contar(18, 3, 2200, (v) => { d.textContent = String(Math.round(v)); });
  });
  unaVez(".odo", (el) => {
    const b = document.querySelector("[data-odo]"), bar = document.querySelector("[data-odo-bar]");
    bar.style.width = "98%"; bar.style.background = "var(--amber)";
    contar(2380, 2496, 2200, (v) => { const s = String(Math.round(v)); b.textContent = s.slice(0, -3) + "." + s.slice(-3); });
  });
  unaVez(".incdemo", (el) => {
    const st = el.querySelector("[data-state]"), dot = el.querySelector(".dot"), cad = [...el.querySelectorAll(".incdemo__chain span")];
    const fases = [["Abierta", 0], ["Con OT", 1], ["Con OT", 1], ["Completada", 2]];
    fases.forEach(([txt, s], i) => setTimeout(() => {
      st.textContent = txt; st.dataset.s = String(s);
      if (s === 2) dot.style.background = "var(--green)";
      cad.forEach((c, j) => c.classList.toggle("on", j <= i));
    }, quieto ? 0 : 400 + i * 700));
  });

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
