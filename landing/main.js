// Pultec · landing. Sin dependencias: tema claro/oscuro, una aparición en la portada, pasos con vídeo fijo,
// líneas del bloque «El problema» y vídeos que se reproducen una vez, solo a la vista (nada en bucle).
// La app se abre con el mismo tema que la landing (acceso y nombre de la empresa incluidos).
const conTema = (url) => {
  const oscuro = (document.documentElement.dataset.theme || "light") === "dark";
  const u = new URL(url);
  u.searchParams.set("tema", oscuro ? "oscuro" : "claro");
  return u.toString();
};

(() => {
  const root = document.documentElement;
  root.classList.add("js");
  const quieto = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // En local, «Probar» y «Entrar» llevan a la app de Pultec en local (python3 tool/vivo.py --industrial, puerto 8000).
  if (["localhost", "127.0.0.1"].includes(location.hostname)) {
    document.querySelectorAll('a[href^="https://saas-pulpo.pages.dev/industrial/"]').forEach((a) => {
      a.href = a.href.replace("https://saas-pulpo.pages.dev/industrial/", "http://localhost:8000/");
    });
  }

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

  // Facturación mensual / anual y precios con o sin IVA (21 %)
  let k = "Mes", iva = false;
  const euros = (txt) => {
    const n = parseFloat(txt) * (iva ? 1.21 : 1);
    return n.toLocaleString("es-ES", { maximumFractionDigits: 2, minimumFractionDigits: Number.isInteger(n) ? 0 : 2 }) + " €";
  };
  const precios = () => {
    document.querySelectorAll("[data-price-mes]").forEach((p) => { p.textContent = euros(p.dataset["price" + k]); });
    document.querySelectorAll("[data-per-mes]").forEach((p) => { p.textContent = p.dataset["per" + k]; });
    document.querySelectorAll("[data-iva-nota]").forEach((p) => { p.textContent = iva ? "Precios con IVA (21 %)." : "Precios sin IVA."; });
    // Los botones de los planes llevan el periodo elegido a la app (lo usará el paso de pago).
    document.querySelectorAll("[data-plan-pago]").forEach((a) => {
      a.href = a.href.replace(/periodo=\w+/, "periodo=" + (k === "Mes" ? "mensual" : "anual"));
    });
  };
  document.querySelectorAll("[data-billing]").forEach((b) => b.addEventListener("click", () => {
    k = b.dataset.billing === "mes" ? "Mes" : "Anio";
    document.querySelectorAll("[data-billing]").forEach((x) => x.classList.toggle("is-on", x === b));
    precios();
  }));
  document.querySelectorAll("[data-iva]").forEach((b) => b.addEventListener("click", () => {
    iva = b.dataset.iva === "con";
    document.querySelectorAll("[data-iva]").forEach((x) => x.classList.toggle("is-on", x === b));
    precios();
  }));

})();

// Entrar / crear cuenta sin salir de la landing. Habla con Supabase Auth por HTTP (sin librerías) y, con la sesión,
// lleva a la app con los tokens en el fragmento (#access_token=…): supabase_flutter los recoge, guarda la sesión y
// limpia la dirección. El plan elegido (?plan=…&periodo=…) viaja en la query para el paso de pago.
// Sin JS (o si algo falla al cargar) los botones son enlaces normales a la pantalla de acceso de la app.
(() => {
  const dlg = document.getElementById("acceso");
  if (!dlg || typeof dlg.showModal !== "function") return;

  const local = ["localhost", "127.0.0.1"].includes(location.hostname);
  // Clave publicable: es pública por diseño (va también en la app). Local = la de serie de `supabase start`.
  const CFG = local
    // En local, Supabase va por la misma dirección que la landing (tool/landing_local.py la reenvía por dentro).
    ? { api: location.origin, clave: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH", app: `${location.protocol}//${location.hostname}:8000/` }
    : { api: "https://gvasthxiqckmekwvhtrg.supabase.co", clave: "sb_publishable_jGH8ZqhOiUZOttnNh8AOSg_BHvqppBQ", app: "https://saas-pulpo.pages.dev/industrial/" };

  const $ = (id) => document.getElementById(id);
  const form = $("acceso-form"), correo = $("acceso-correo"), clave = $("acceso-clave"), enviar = $("acceso-enviar");
  const aviso = $("acceso-aviso"), google = $("acceso-google");
  let modo = "registro", plan = null, periodo = null, enviando = false;

  const TEXTOS = {
    registro: { titulo: "Crea tu cuenta", sub: "14 días gratis y sin tarjeta. En dos minutos tienes tu primera máquina.", boton: "Crear cuenta",
                cambioTexto: "¿Ya tienes cuenta?", cambio: "Entra" },
    entrar:   { titulo: "Entra en Pultec", sub: "Con tu correo y tu contraseña.", boton: "Entrar",
                cambioTexto: "¿Aún no tienes cuenta?", cambio: "Pruébalo gratis" },
  };

  // Dirección de la app a la que se vuelve (con el plan elegido, si lo hay).
  const urlApp = () => {
    const u = new URL(CFG.app);
    if (plan) u.searchParams.set("plan", plan);
    if (periodo) u.searchParams.set("periodo", periodo);
    return conTema(u.toString());
  };

  const pintar = () => {
    const t = TEXTOS[modo];
    $("acceso-titulo").textContent = t.titulo;
    $("acceso-sub").textContent = plan && modo === "registro"
      ? "14 días gratis y sin tarjeta; activas el plan cuando quieras desde Ajustes → Plan." : t.sub;
    enviar.textContent = t.boton;
    $("acceso-cambio-texto").textContent = t.cambioTexto;
    $("acceso-cambio").textContent = t.cambio;
    $("acceso-olvido").hidden = modo !== "entrar";
    clave.autocomplete = modo === "entrar" ? "current-password" : "new-password";
    const p = $("acceso-plan");
    p.hidden = !plan || modo !== "registro";
    p.textContent = `Plan ${{ basico: "Básico", estandar: "Estándar", premium: "Premium" }[plan] ?? ""} ${periodo === "anual" ? "anual" : "mensual"}`;
  };

  const ponerAviso = (texto, bueno = false, accion = null) => {
    aviso.hidden = !texto;
    aviso.classList.toggle("es-bueno", bueno);
    aviso.textContent = texto || "";
    if (accion) {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = accion.texto;
      b.addEventListener("click", accion.hacer);
      aviso.append(" ", b);
    }
  };

  // Los errores de Supabase llegan en inglés: cada uno con una frase que diga qué hacer (las mismas que la app).
  const traducir = (m) => {
    const t = String(m || "").toLowerCase();
    if (t.includes("invalid login")) return "Correo o contraseña incorrectos. Revísalos o pulsa «¿Has olvidado la contraseña?».";
    if (t.includes("already registered") || t.includes("already been registered")) return "Ya hay una cuenta con ese correo. Entra con ella o recupera la contraseña.";
    if (t.includes("not confirmed")) return "Falta confirmar el correo. Abre el enlace que te enviamos o pide otro.";
    if (t.includes("rate limit") || t.includes("security purposes")) return "Demasiados intentos seguidos. Espera un minuto y vuelve a probar.";
    if (t.includes("password")) return "La contraseña no vale: usa al menos 6 caracteres.";
    if (t.includes("email") && (t.includes("invalid") || t.includes("validate"))) return "Ese correo no es válido. Revisa que esté bien escrito.";
    if (t.includes("signups not allowed") || t.includes("signup is disabled")) return "Ahora no se pueden crear cuentas. Pide a tu empresa que te invite.";
    return "Algo ha fallado. Vuelve a intentarlo en un momento.";
  };

  const auth = async (ruta, cuerpo, redirigir = false) => {
    const q = redirigir ? `${ruta.includes("?") ? "&" : "?"}redirect_to=${encodeURIComponent(urlApp())}` : "";
    let r;
    try {
      r = await fetch(`${CFG.api}/auth/v1/${ruta}${q}`, {
        method: "POST",
        headers: { apikey: CFG.clave, "Content-Type": "application/json" },
        body: JSON.stringify(cuerpo),
      });
    } catch {
      throw new Error("sin-conexion");
    }
    const datos = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(datos.msg || datos.error_description || datos.message || datos.error || "error");
    return datos;
  };

  // Lleva a la app con la sesión: supabase_flutter necesita access_token, refresh_token, expires_in y token_type.
  const irALaApp = (s) => {
    const f = new URLSearchParams({
      access_token: s.access_token,
      refresh_token: s.refresh_token,
      expires_in: String(s.expires_in),
      expires_at: String(s.expires_at || ""),
      token_type: s.token_type || "bearer",
      type: modo === "registro" ? "signup" : "login",
    });
    location.assign(`${urlApp()}#${f}`);
  };

  const ocupado = (si) => {
    enviando = si;
    enviar.disabled = si;
    enviar.textContent = si ? "Un momento…" : TEXTOS[modo].boton;
  };

  const intentar = async (fn) => {
    if (enviando) return;
    ponerAviso(null);
    ocupado(true);
    try {
      await fn();
    } catch (e) {
      ponerAviso(e.message === "sin-conexion" ? "No se pudo conectar. Comprueba la conexión y vuelve a intentarlo." : traducir(e.message));
      ocupado(false);
    }
  };

  const correoValido = () => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo.value.trim());

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const email = correo.value.trim(), password = clave.value;
    if (!correoValido()) return ponerAviso("Revisa el correo: falta algo (como nombre@empresa.com).");
    if (password.length < 6) return ponerAviso("La contraseña necesita al menos 6 caracteres.");
    intentar(async () => {
      if (modo === "entrar") return irALaApp(await auth("token?grant_type=password", { email, password }));
      const r = await auth("signup", { email, password }, true);
      if (r.access_token) return irALaApp(r);
      // Con confirmación de correo activada no hay sesión todavía: el enlace del correo abre la app ya dentro.
      ocupado(false);
      ponerAviso(`Te hemos enviado un correo a ${email}. Ábrelo para confirmar la cuenta y entrarás directamente.`, true,
        { texto: "Reenviar", hacer: () => intentar(async () => {
          await auth("resend", { type: "signup", email }, true);
          ocupado(false);
          ponerAviso("Te lo hemos vuelto a enviar. Mira también en spam.", true);
        }) });
    });
  });

  $("acceso-olvido").addEventListener("click", () => {
    if (!correoValido()) return ponerAviso("Escribe arriba tu correo y vuelve a pulsar.");
    intentar(async () => {
      await auth("recover", { email: correo.value.trim() }, true);
      ocupado(false);
      ponerAviso("Si hay una cuenta con ese correo, te llegará un enlace para poner otra contraseña.", true);
    });
  });

  // Google solo si está activado en esta Supabase (en local normalmente no). Vuelve a la app con la sesión.
  fetch(`${CFG.api}/auth/v1/settings`, { headers: { apikey: CFG.clave } })
    .then((r) => r.json())
    .then((s) => { if (s?.external?.google) { google.hidden = false; $("acceso-o").hidden = false; } })
    .catch(() => {});
  google.addEventListener("click", () => {
    location.assign(`${CFG.api}/auth/v1/authorize?provider=google&redirect_to=${encodeURIComponent(urlApp())}`);
  });

  $("acceso-ver").addEventListener("click", (e) => {
    const ver = clave.type === "password";
    clave.type = ver ? "text" : "password";
    e.currentTarget.textContent = ver ? "Ocultar" : "Ver";
    e.currentTarget.setAttribute("aria-pressed", String(ver));
  });

  $("acceso-cambio").addEventListener("click", () => {
    // Entrar ya no se hace aquí: lleva a la pantalla de acceso de la app.
    if (modo === "registro") { location.href = conTema(CFG.app); return; }
    modo = "registro";
    ponerAviso(null);
    pintar();
    correo.focus();
  });

  const cerrar = () => dlg.close();
  dlg.querySelector("[data-cerrar]").addEventListener("click", cerrar);
  dlg.addEventListener("click", (e) => { if (e.target === dlg) cerrar(); }); // clic fuera de la tarjeta

  document.querySelectorAll("[data-acceso]").forEach((a) => a.addEventListener("click", (e) => {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.button === 1) return; // abrir en otra pestaña: enlace normal
    e.preventDefault();
    // «Entrar» va directo a la pantalla de acceso de la app (correo y contraseña allí); crear cuenta sigue aquí.
    if (a.dataset.acceso === "entrar") { location.href = conTema(CFG.app); return; }
    const q = new URL(a.href).searchParams;
    modo = a.dataset.acceso;
    plan = q.get("plan");
    periodo = q.get("periodo");
    ponerAviso(null);
    ocupado(false);
    pintar();
    dlg.showModal();
    correo.focus();
  }));
})();

// Entrada: el pulpo cae grande en el centro, saca los tentáculos, guiña y vuela a su sitio en la barra.
// Un clic, una tecla o la rueda la saltan. Sin movimiento reducido no se monta (html.intro lo pone el <head>).
(() => {
  const root = document.documentElement;
  const capa = document.getElementById("intro-pulpo");
  if (!capa || !root.classList.contains("intro")) return;
  const svg = capa.querySelector("svg");
  const cabeza = capa.querySelector(".intro-pulpo__cuerpo");
  const ojos = capa.querySelectorAll(".intro-pulpo__ojos circle");
  const tentaculos = [...capa.querySelectorAll(".intro-t")];
  const destino = document.querySelector(".nav .brand img");
  const anims = [];
  const a = (el, kf, op) => { const x = el.animate(kf, { fill: "both", ...op }); anims.push(x); return x; };
  const rebote = "cubic-bezier(.34,1.56,.64,1)";
  let fin = false;

  const terminar = () => {
    if (fin) return;
    fin = true;
    root.classList.remove("intro");
    capa.remove();
    ["click", "keydown", "wheel", "touchstart"].forEach((e) => removeEventListener(e, saltar));
  };
  const saltar = () => { anims.forEach((x) => x.finish()); terminar(); };
  ["click", "keydown", "wheel", "touchstart"].forEach((e) => addEventListener(e, saltar, { passive: true }));

  // 1. Cae y rebota (estira y aplasta), ya con el arranque de los tentáculos para que no se vea la base plana.
  a(cabeza, [
    { opacity: 0, transform: "translateY(-120px) scale(.6, .9)" },
    { opacity: 1, transform: "translateY(0) scale(1.12, .86)", offset: 0.55 },
    { transform: "translateY(-14px) scale(.95, 1.06)", offset: 0.8 },
    { opacity: 1, transform: "none" },
  ], { duration: 700, easing: "ease-out" });

  // 2. Los tentáculos salen uno a uno, de dentro hacia fuera, alternando lados, y se mecen.
  const orden = [0, 3, 1, 4, 2, 5];
  orden.forEach((i, n) => {
    const t = tentaculos[i];
    const lado = i < 3 ? -1 : 1;
    a(t, [{ strokeDashoffset: 0.8 }, { strokeDashoffset: 0 }], { duration: 650, delay: 350 + n * 90, easing: "cubic-bezier(.2,.8,.2,1)" });
    a(t, [
      { transform: `rotate(${lado * -18}deg)` },
      { transform: `rotate(${lado * 8}deg)`, offset: 0.5 },
      { transform: `rotate(${lado * -4}deg)`, offset: 0.75 },
      { transform: "none" },
    ], { duration: 1100, delay: 450 + n * 90, easing: "ease-in-out" });
  });

  // 3. Parpadeo.
  ojos.forEach((o) => a(o, [
    { transform: "scaleY(1)" }, { transform: "scaleY(.1)", offset: 0.5 }, { transform: "scaleY(1)" },
  ], { duration: 220, delay: 1650, easing: "ease-in-out" }));

  // 4. Vuela a la barra (de su tamaño y posición al del logo de arriba) y la capa se desvanece.
  setTimeout(() => {
    if (fin) return;
    const de = svg.getBoundingClientRect();
    const a2 = destino ? destino.getBoundingClientRect() : { left: 24, top: 20, width: 34, height: 34 };
    // El PNG de la barra deja ~8 % de margen: se apunta a su zona útil.
    const util = a2.width * 0.92;
    const s = util / de.width;
    const dx = a2.left + a2.width / 2 - (de.left + de.width / 2);
    const dy = a2.top + a2.height / 2 - (de.top + de.height / 2);
    a(svg, [
      { transform: "none" },
      { transform: `translate(${dx * 0.15}px, ${dy * 0.05 - 20}px) scale(1.05)`, offset: 0.2 },
      { transform: `translate(${dx}px, ${dy}px) scale(${s})` },
    ], { duration: 750, easing: "cubic-bezier(.65,0,.25,1)" });
    a(capa, [{ backgroundColor: getComputedStyle(capa).backgroundColor }, { backgroundColor: "transparent" }],
      { duration: 500, delay: 250, easing: "ease-out" }).finished.then(() => {}, () => {});
    setTimeout(terminar, 760);
  }, 2050);
})();
