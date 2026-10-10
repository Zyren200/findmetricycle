// Prism Night presentation layer (ported from the design). Purely visual:
// it never touches React state.
//  - staggered blur-to-sharp reveals when a page opens, scroll reveals below the fold
//  - the sliding nav pill, the prism sweep under the nav on a route change, the scrolled nav
//  - pointer catch-light on glass rims + spotlight, a gentle 3D tilt on feature cards (fine pointers only)

const UNITS =
  ".head, .hero > div > :not(.kpis), .kpis > *, .phone, .grid > *, .shots-row > *, .wrap > h3, section > .wrap > .row, section > .wrap > .alert, section > .wrap > .card, .form-card, .wiz, .status-hero";
const TILT = ".grid > .card.glass, .phone";

export function installPrismFx({ app, tabs, header }) {
  const root = document.documentElement;
  const RM = matchMedia("(prefers-reduced-motion: reduce)");
  const FINE = matchMedia("(hover: hover) and (pointer: fine)");
  const motion = () => !RM.matches;
  const raf2 = (fn) => requestAnimationFrame(() => requestAnimationFrame(fn));
  const cleanups = [];
  root.classList.add("fx");

  /* ---------- sliding nav pill ---------- */
  let pillReady = false;
  function placePill(instant) {
    const on = tabs.querySelector("a.on");
    if (!on || getComputedStyle(tabs).flexDirection === "column") {
      tabs.classList.remove("has-pill");
      return;
    }
    const jump = instant || !pillReady || !tabs.classList.contains("has-pill");
    if (jump) tabs.classList.add("pill-instant");
    const li = on.closest("li") || on;
    tabs.style.setProperty("--px", li.offsetLeft + on.offsetLeft + "px");
    tabs.style.setProperty("--pw", on.offsetWidth + "px");
    tabs.classList.add("has-pill");
    if (jump) raf2(() => tabs.classList.remove("pill-instant"));
    pillReady = true;
  }
  const tabsObserver = new MutationObserver((muts) => {
    if (muts.some((m) => m.target !== tabs)) placePill(false);
  });
  tabsObserver.observe(tabs, { childList: true, subtree: true, attributes: true, attributeFilter: ["class"] });
  cleanups.push(() => tabsObserver.disconnect());
  let rz = 0;
  const onResize = () => {
    cancelAnimationFrame(rz);
    rz = requestAnimationFrame(() => placePill(true));
  };
  addEventListener("resize", onResize, { passive: true });
  cleanups.push(() => removeEventListener("resize", onResize));
  document.fonts?.ready.then(() => placePill(true));
  placePill(true);

  /* ---------- nav: scrolled state + route sweep ---------- */
  let sy = 0;
  const onScroll = () => {
    sy = 0;
    header.classList.toggle("scrolled", scrollY > 8);
  };
  const onScrollRaw = () => {
    if (!sy) sy = requestAnimationFrame(onScroll);
  };
  addEventListener("scroll", onScrollRaw, { passive: true });
  cleanups.push(() => removeEventListener("scroll", onScrollRaw));
  onScroll();
  function sweep() {
    if (!motion()) return;
    header.classList.remove("sweep");
    void header.offsetWidth;
    header.classList.add("sweep");
  }

  /* ---------- reveal units ---------- */
  function units(page) {
    const picked = new Set();
    for (const el of page.querySelectorAll(UNITS)) {
      let p = el.parentElement;
      let nested = false;
      while (p && p !== page) {
        if (picked.has(p)) {
          nested = true;
          break;
        }
        p = p.parentElement;
      }
      if (!nested) picked.add(el);
    }
    // Never fade a non-glass wrapper around glass: an ancestor with opacity < 1
    // cuts the glass off from the sky behind it.
    const out = [];
    const add = (el) => {
      if (!el.classList.contains("glass") && el.querySelector(".glass")) [...el.children].forEach(add);
      else out.push(el);
    };
    picked.forEach(add);
    return out;
  }
  let io = null;
  function onIntersect(entries) {
    const vis = entries
      .filter((e) => e.isIntersecting)
      .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top || a.boundingClientRect.left - b.boundingClientRect.left);
    vis.forEach((e, k) => {
      e.target.style.setProperty("--d", Math.min(k, 6) * 75 + "ms");
      e.target.classList.add("in");
      io?.unobserve(e.target);
    });
  }
  function reveal(page) {
    if (!motion()) return;
    io?.disconnect();
    io = "IntersectionObserver" in window ? new IntersectionObserver(onIntersect, { rootMargin: "0px 0px -6% 0px", threshold: 0.01 }) : null;
    const vh = innerHeight;
    let i = 0;
    for (const el of units(page)) {
      el.classList.add("rv");
      if (!io || el.getBoundingClientRect().top < vh * 0.96) {
        el.style.setProperty("--d", Math.min(i++, 8) * 62 + "ms");
        el.classList.add("in");
      } else io.observe(el);
    }
  }
  const pageObserver = new MutationObserver((muts) => {
    for (const m of muts) {
      for (const n of m.addedNodes) {
        if (n.nodeType === 1 && n.classList.contains("page")) {
          reveal(n);
          sweep();
          return;
        }
      }
    }
  });
  pageObserver.observe(app, { childList: true });
  cleanups.push(() => {
    pageObserver.disconnect();
    io?.disconnect();
  });
  const first = app.querySelector(":scope > .page");
  if (first) reveal(first);

  /* ---------- pointer light + tilt ---------- */
  let lit = null;
  let ev = null;
  let tick = 0;
  function unlight(el) {
    el.classList.remove("lit", "tilting");
    for (const v of ["--rx", "--ry"]) el.style.setProperty(v, "0deg");
    for (const v of ["--tx", "--ty"]) el.style.setProperty(v, "0");
  }
  function frame() {
    tick = 0;
    const e = ev;
    if (!e) return;
    if (lit && !lit.isConnected) lit = null;
    const t = e.target instanceof Element ? e.target : null;
    const g = t && t.closest(".glass");
    if (g !== lit) {
      if (lit) unlight(lit);
      lit = g;
      g?.classList.add("lit");
    }
    if (g) {
      const r = g.getBoundingClientRect();
      const x = e.clientX - r.left;
      const y = e.clientY - r.top;
      g.style.setProperty("--mx", x.toFixed(1) + "px");
      g.style.setProperty("--my", y.toFixed(1) + "px");
      if (motion() && g.matches(TILT)) {
        const nx = Math.max(-1, Math.min(1, (x / r.width) * 2 - 1));
        const ny = Math.max(-1, Math.min(1, (y / r.height) * 2 - 1));
        const k = g.classList.contains("phone") ? 0.55 : 1;
        g.classList.add("tilting");
        g.style.setProperty("--rx", (-ny * 5 * k).toFixed(2) + "deg");
        g.style.setProperty("--ry", (nx * 7 * k).toFixed(2) + "deg");
        g.style.setProperty("--tx", nx.toFixed(3));
        g.style.setProperty("--ty", ny.toFixed(3));
      }
    }
    const b = t && t.closest(".btn-hot");
    if (b) {
      const r = b.getBoundingClientRect();
      b.style.setProperty("--bx", (e.clientX - r.left).toFixed(1) + "px");
      b.style.setProperty("--by", (e.clientY - r.top).toFixed(1) + "px");
    }
  }
  const onMove = (e) => {
    if (e.pointerType !== "mouse" || !FINE.matches) return;
    ev = e;
    if (!tick) tick = requestAnimationFrame(frame);
  };
  const onOut = (e) => {
    if (e.relatedTarget) return;
    ev = null;
    if (lit) {
      unlight(lit);
      lit = null;
    }
  };
  document.addEventListener("pointermove", onMove, { passive: true });
  document.addEventListener("pointerout", onOut, { passive: true });
  cleanups.push(() => {
    document.removeEventListener("pointermove", onMove);
    document.removeEventListener("pointerout", onOut);
  });

  return () => cleanups.forEach((fn) => fn());
}
