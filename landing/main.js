// Pultec · landing. Sin dependencias: aparición al hacer scroll, pasos con vídeo fijo, vídeos que solo
// se reproducen a la vista, demos de las tarjetas y cambio de facturación.
(() => {
  const root = document.documentElement;
  root.classList.add("js");
  const quieto = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Barra con borde al bajar
  const nav = document.getElementById("nav");
  const onScroll = () => nav.classList.toggle("is-scrolled", scrollY > 8);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Aparición
  const io = new IntersectionObserver((es) => {
    es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("is-in"); io.unobserve(e.target); } });
  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
  document.querySelectorAll(".reveal, .tile").forEach((el) => io.observe(el));

  // Cinta de sectores: se duplica para que no tenga fin
  const track = document.querySelector(".marquee__track");
  if (track && !quieto) track.innerHTML += track.innerHTML;

  // Vídeos: carga perezosa y solo se reproducen mientras se ven (ahorra batería y datos)
  const reproducir = (v) => { const p = v.play(); if (p) p.catch(() => {}); };
  const vio = new IntersectionObserver((es) => {
    es.forEach(({ target: v, isIntersecting }) => {
      if (isIntersecting) {
        if (v.dataset.src && !v.src) { v.src = v.dataset.src; }
        if (!quieto) reproducir(v);
      } else if (!v.paused) v.pause();
    });
  }, { threshold: 0.25 });
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

  // Cómo funciona: el paso centrado cambia el vídeo fijo (fundido entre dos <video>)
  const pasos = [...document.querySelectorAll(".step")];
  const capas = [...document.querySelectorAll(".stage__video")];
  const barra = document.getElementById("progreso");
  let actual = 0, capa = 0;
  const activar = (i) => {
    if (i === actual) return;
    actual = i;
    pasos.forEach((p, j) => p.classList.toggle("is-active", j === i));
    if (barra) barra.style.width = ((i + 1) / pasos.length) * 100 + "%";
    const sig = capas[1 - capa];
    sig.src = pasos[i].dataset.video;
    sig.poster = pasos[i].dataset.poster;
    sig.currentTime = 0;
    if (!quieto) reproducir(sig);
    sig.classList.add("is-on");
    capas[capa].classList.remove("is-on");
    const viejo = capas[capa];
    setTimeout(() => viejo.pause(), 520);
    capa = 1 - capa;
  };
  if (capas.length) {
    const pio = new IntersectionObserver((es) => {
      es.forEach((e) => { if (e.isIntersecting) activar(pasos.indexOf(e.target)); });
    }, { rootMargin: "-45% 0px -45% 0px" });
    pasos.forEach((p) => pio.observe(p));
    const stage = document.querySelector(".story__stage");
    new IntersectionObserver(([e]) => {
      const v = capas[capa];
      if (e.isIntersecting && !quieto) reproducir(v); else v.pause();
    }, { threshold: 0.1 }).observe(stage);
  }

  // Demos de las tarjetas (solo mientras se ven)
  const visible = new Set();
  const tio = new IntersectionObserver((es) => es.forEach((e) => e.isIntersecting ? visible.add(e.target) : visible.delete(e.target)), { threshold: 0.3 });
  document.querySelectorAll(".tile").forEach((t) => tio.observe(t));
  const ve = (sel) => { const el = document.querySelector(sel); return el && visible.has(el.closest(".tile")) ? el : null; };

  // Anillo del ciclo: los días bajan y el color cambia (verde, ámbar <20 %, rojo <10 %)
  const ringF = document.querySelector(".ringdemo .rf");
  const ringD = document.querySelector("[data-ring-days]");
  let dias = 30;
  // Contador por horas
  const odo = document.querySelector("[data-odo]");
  const odoBar = document.querySelector("[data-odo-bar]");
  let horas = 2380;
  // Incidencia: estados
  const estado = document.querySelector("[data-state]");
  const dot = document.querySelector(".incdemo .dot");
  const cadena = [...document.querySelectorAll(".incdemo__chain span")];
  let paso = 0;
  // Avisos
  const toasts = [...document.querySelectorAll(".toast")];
  let tIdx = 0;
  const colocarToasts = () => toasts.forEach((t, i) => {
    const pos = (i - tIdx + toasts.length) % toasts.length; // 0 delante
    t.style.transform = `translateY(${pos * 22}px) scale(${1 - pos * 0.05})`;
    t.style.opacity = pos === toasts.length - 1 ? 0 : 1 - pos * 0.5;
    t.style.zIndex = String(10 - pos);
  });
  colocarToasts();

  const tic = () => {
    if (ve(".ringdemo")) {
      dias = dias <= 0 ? 30 : dias - 1;
      const f = dias / 30;
      ringF.style.strokeDashoffset = String(100 - f * 100);
      ringF.style.stroke = f < 0.1 ? "var(--red)" : f < 0.2 ? "var(--amber)" : "var(--green)";
      ringD.textContent = String(dias);
    }
    if (ve("[data-odo]")) {
      horas = horas >= 2500 ? 2380 : horas + 4;
      const s = String(horas);
      odo.textContent = s.slice(0, -3) + "." + s.slice(-3);
      odoBar.style.width = ((horas - 2250) / 250) * 100 + "%";
      odoBar.style.background = horas >= 2480 ? "var(--red)" : horas >= 2450 ? "var(--amber)" : "var(--purple)";
    }
  };
  const ticLento = () => {
    if (ve("[data-state]")) {
      paso = (paso + 1) % 4;
      const s = Math.min(paso, 2);
      estado.dataset.s = String(s);
      estado.textContent = ["Abierta", "Con OT", "Completada"][s];
      dot.style.background = s === 2 ? "var(--green)" : "var(--red)";
      cadena.forEach((c, i) => c.classList.toggle("on", i <= paso));
    }
    if (ve(".toasts")) { tIdx = (tIdx + 1) % toasts.length; colocarToasts(); }
  };
  if (!quieto) { setInterval(tic, 140); setInterval(ticLento, 1500); }
  else { cadena.forEach((c) => c.classList.add("on")); }

  // Facturación mensual / anual
  document.querySelectorAll("[data-billing]").forEach((b) => b.addEventListener("click", () => {
    const k = b.dataset.billing;
    document.querySelectorAll("[data-billing]").forEach((x) => x.classList.toggle("is-on", x === b));
    document.querySelectorAll("[data-price-mes]").forEach((p) => { p.textContent = p.dataset["price" + (k === "mes" ? "Mes" : "Anio")]; });
    document.querySelectorAll("[data-per-mes]").forEach((p) => { p.textContent = p.dataset["per" + (k === "mes" ? "Mes" : "Anio")]; });
  }));

  // Paralaje suave de la foto
  const foto = document.querySelector(".photo__img");
  if (foto && !quieto) {
    const mover = () => {
      const r = foto.parentElement.getBoundingClientRect();
      if (r.bottom < 0 || r.top > innerHeight) return;
      const p = (r.top + r.height / 2 - innerHeight / 2) / innerHeight;
      foto.style.transform = `translateY(${p * -60}px)`;
    };
    addEventListener("scroll", mover, { passive: true });
    mover();
  }
})();
