/* ظِلّ — منطق الواجهة
 * يقرأ المناطق من الـ Backend (GET /api/areas/) ويعرضها على الخريطة والقوائم.
 * لا توجد أي أرقام افتراضية هنا: كل الأرقام تأتي من الـ API.
 */
(() => {
  "use strict";

  const CFG = window.ZILL_CONFIG;
  const T = CFG.HEAT_THRESHOLDS;

  const HEAT_LEVELS = [
    { key: "extreme", color: "#EF4444", label: `أعلى حرارة (أكثر من ${T.extreme}°م)`, short: "شديدة الحرارة" },
    { key: "hot",     color: "#F97316", label: `حارة (${T.hot}–${T.extreme}°م)`,        short: "حارة" },
    { key: "warm",    color: "#FACC15", label: `متوسطة (${T.warm}–${T.hot}°م)`,         short: "متوسطة الحرارة" },
    { key: "cool",    color: "#38BDF8", label: `أقل حرارة (أقل من ${T.warm}°م)`,        short: "أقل حرارة" },
  ];
  const NO_DATA_COLOR = "#9CA3AF";

  // تصنيف فريق البيانات (بالإنجليزية) ← عرض عربي
  const CLASS_AR = {
    hotter: "مرتفعة الحرارة", hot: "مرتفعة الحرارة", high: "مرتفعة الحرارة",
    moderate: "متوسطة الحرارة", medium: "متوسطة الحرارة",
    cooler: "منخفضة الحرارة", cool: "منخفضة الحرارة", low: "منخفضة الحرارة",
  };

  const state = { areas: [], selectedId: null, map: null, layers: new Map(), loaded: false };

  // ---------- أدوات ----------
  const $ = (sel) => document.querySelector(sel);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const num = (v) => (v === null || v === undefined || v === "" || isNaN(Number(v)) ? null : Number(v));
  const fmt = (v, d = 1) => (v === null ? "—" : v.toLocaleString("ar-u-nu-latn", { minimumFractionDigits: d, maximumFractionDigits: d }));

  function heatLevel(t) {
    if (t === null) return null;
    if (t > T.extreme) return HEAT_LEVELS[0];
    if (t >= T.hot) return HEAT_LEVELS[1];
    if (t >= T.warm) return HEAT_LEVELS[2];
    return HEAT_LEVELS[3];
  }
  const heatColor = (t) => heatLevel(t)?.color ?? NO_DATA_COLOR;

  function classificationAr(a) {
    if (a.classification) {
      return CLASS_AR[String(a.classification).trim().toLowerCase()] ?? a.classification;
    }
    // إذا لم يرسل فريق البيانات تصنيفاً نستخدم عتبات README
    if (a.temperature === null) return "غير متوفر";
    if (a.temperature > T.extreme) return "مرتفعة الحرارة";
    if (a.temperature >= T.warm) return "متوسطة الحرارة";
    return "منخفضة الحرارة";
  }

  function isCandidate(a) {
    return a.temperature !== null && a.ndvi !== null &&
      a.temperature >= CFG.PLANTING_MIN_TEMP && a.ndvi < CFG.PLANTING_MAX_NDVI;
  }

  function priorityLevel(a) {
    const p = a.priority;
    if (p === null || p <= 0) return { key: "none", label: "غير مرشحة" };
    if (p >= 70) return { key: "high", label: "أولوية عالية" };
    if (p >= 40) return { key: "medium", label: "أولوية متوسطة" };
    return { key: "low", label: "أولوية منخفضة" };
  }

  // سبب اختيار المنطقة — يُبنى من أرقام المنطقة نفسها ومعايير التحليل
  function reasons(a) {
    const r = [];
    if (a.temperature !== null) {
      r.push(a.temperature >= CFG.PLANTING_MIN_TEMP
        ? `حرارة سطح الأرض ${fmt(a.temperature)}°م، وهي أعلى من عتبة ${CFG.PLANTING_MIN_TEMP}°م المعتمدة في التحليل.`
        : `حرارة سطح الأرض ${fmt(a.temperature)}°م، وهي أقل من عتبة ${CFG.PLANTING_MIN_TEMP}°م.`);
    }
    if (a.ndvi !== null) {
      r.push(a.ndvi < CFG.PLANTING_MAX_NDVI
        ? `الغطاء النباتي ضعيف: قيمة NDVI هي ${fmt(a.ndvi, 2)}، أي أقل من ${CFG.PLANTING_MAX_NDVI}.`
        : `يوجد غطاء نباتي مقبول: قيمة NDVI هي ${fmt(a.ndvi, 2)}.`);
    }
    if (a.priority !== null && a.priority > 0) {
      r.push(`درجة أولوية التشجير ${fmt(a.priority, 0)} من 100، وتجمع بين شدة الحرارة والقرب من المياه وقدرة التربة على حفظ الماء.`);
    }
    if (a.reason) r.push(a.reason); // إن أرسل الـ Backend سبباً جاهزاً
    if (!r.length) r.push("لا تتوفر بيانات كافية لهذه المنطقة.");
    return r;
  }

  function normalize(raw, i) {
    return {
      id: raw.id ?? i + 1,
      name: raw.name ?? `منطقة ${i + 1}`,
      temperature: num(raw.temperature),
      classification: raw.classification ?? null,
      ndvi: num(raw.ndvi),
      priority: num(raw.planting_priority),
      reason: raw.reason ?? null,
      impact: raw.cooling_estimate ?? raw.impact ?? null, // تقدير تأثير التشجير إن توفر علمياً
      geometry: raw.geometry ?? null,                     // GeoJSON اختياري
      lat: num(raw.lat ?? raw.latitude),
      lng: num(raw.lng ?? raw.lon ?? raw.longitude),
    };
  }

  // ---------- جلب البيانات ----------
  async function loadAreas() {
    showToast("جارٍ تحميل البيانات…");
    try {
      const res = await fetch(CFG.API_BASE + CFG.AREAS_ENDPOINT, { headers: { Accept: "application/json" } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const list = Array.isArray(data) ? data : (data.areas ?? []);
      state.areas = list.map(normalize);
      state.loaded = true;
      hideToast();
      renderAll();
    } catch (err) {
      console.error("تعذر تحميل المناطق:", err);
      showToast("تعذر الاتصال بالخادم. تأكد من تشغيل الـ Backend.", true, loadAreas);
      renderAll();
    }
  }

  // ---------- الإحصائيات ----------
  function statsHtml() {
    const a = state.areas;
    const temps = a.map((x) => x.temperature).filter((t) => t !== null);
    const hot = a.filter((x) => x.temperature !== null && x.temperature >= T.hot).length;
    const need = a.filter((x) => (x.priority ?? 0) > 0 || isCandidate(x)).length;
    const max = temps.length ? Math.max(...temps) : null;
    const avg = temps.length ? temps.reduce((s, t) => s + t, 0) / temps.length : null;
    return `
      <div class="stat"><div class="value">${fmt(a.length, 0)}</div><div class="label">منطقة محللة</div></div>
      <div class="stat hot"><div class="value">${fmt(hot, 0)}</div><div class="label">منطقة حارة (${T.hot}°م فأكثر)</div></div>
      <div class="stat warn"><div class="value">${fmt(need, 0)}</div><div class="label">تحتاج إلى تشجير</div></div>
      <div class="stat"><div class="value">${max === null ? "—" : fmt(max) + "°"}</div><div class="label">أعلى حرارة سطح</div></div>
      <div class="stat"><div class="value">${avg === null ? "—" : fmt(avg) + "°"}</div><div class="label">متوسط الحرارة</div></div>`;
  }

  function renderStats() {
    $("#dash-stats").innerHTML = statsHtml();
    if (state.areas.length) {
      $("#home-stats").innerHTML = statsHtml();
      $("#home-summary").hidden = false;
    }
  }

  // ---------- الخريطة ----------
  function initMap() {
    if (state.map) return;
    state.map = L.map("map", { zoomControl: true }).setView(CFG.CITY_CENTER, CFG.CITY_ZOOM);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(state.map);
    renderMapLayers();
  }

  function popupHtml(a) {
    return `<strong>${esc(a.name)}</strong><br>
      <span class="popup-temp" style="color:${heatColor(a.temperature)}">${a.temperature === null ? "—" : fmt(a.temperature) + "°م"}</span><br>
      <span class="muted small">${esc(classificationAr(a))}</span>`;
  }

  function styleFor(a, selected) {
    const c = heatColor(a.temperature);
    return { color: selected ? "#14532D" : c, weight: selected ? 4 : 2, fillColor: c, fillOpacity: selected ? 0.6 : 0.45 };
  }

  function renderMapLayers() {
    if (!state.map) return;
    state.layers.forEach((l) => l.remove());
    state.layers.clear();

    const noGeo = [];
    const bounds = [];
    const single = state.areas.length === 1;

    state.areas.forEach((a) => {
      let layer = null;
      if (a.geometry) {
        layer = L.geoJSON(a.geometry, { style: () => styleFor(a, false) });
      } else if (a.lat !== null && a.lng !== null) {
        layer = L.circleMarker([a.lat, a.lng], { ...styleFor(a, false), radius: 14 });
      } else if (single) {
        // منطقة واحدة بدون إحداثيات (مثل «محافظة بغداد») نعرضها على مركز المدينة
        layer = L.circle(CFG.CITY_CENTER, { ...styleFor(a, false), radius: 18000 });
      } else {
        noGeo.push(a);
        return;
      }
      layer.bindPopup(popupHtml(a));
      layer.on("click", () => selectArea(a.id, false));
      layer.addTo(state.map);
      state.layers.set(a.id, layer);
      const b = layer.getBounds ? layer.getBounds() : L.latLng(a.lat, a.lng).toBounds(500);
      if (b.isValid()) bounds.push(b);
    });

    if (bounds.length) {
      const all = bounds.reduce((acc, b) => acc.extend(b), L.latLngBounds(bounds[0].getSouthWest(), bounds[0].getNorthEast()));
      state.map.fitBounds(all, { padding: [30, 30], maxZoom: 13 });
    }

    const note = $("#no-geo-note");
    note.hidden = !noGeo.length;
    note.textContent = noGeo.length ? `${fmt(noGeo.length, 0)} منطقة لا تملك إحداثيات بعد، لذلك تظهر في القائمة فقط.` : "";
  }

  function renderLegend() {
    $("#legend-list").innerHTML = HEAT_LEVELS.map((l) =>
      `<li><span class="swatch" style="background:${l.color}"></span>${l.label}</li>`).join("");
  }

  // ---------- القائمة والتفاصيل ----------
  function renderAreaList() {
    const list = $("#area-list");
    if (!state.areas.length) {
      list.innerHTML = `<li class="empty">${state.loaded ? "لا توجد مناطق في قاعدة البيانات بعد." : "لا توجد بيانات."}</li>`;
      return;
    }
    const sorted = [...state.areas].sort((x, y) => (y.temperature ?? -999) - (x.temperature ?? -999));
    list.innerHTML = sorted.map((a) => `
      <li><button class="area-item ${a.id === state.selectedId ? "selected" : ""}" data-id="${esc(a.id)}">
        <span class="dot" style="background:${heatColor(a.temperature)}"></span>
        <span class="name">${esc(a.name)}</span>
        <span class="temp">${a.temperature === null ? "—" : fmt(a.temperature) + "°"}</span>
      </button></li>`).join("");
  }

  function renderDetails() {
    const box = $("#area-details");
    const a = state.areas.find((x) => String(x.id) === String(state.selectedId));
    $("#area-list-wrap").hidden = !!a;
    box.hidden = !a;
    if (!a) return;

    const lvl = heatLevel(a.temperature);
    const pr = priorityLevel(a);
    box.innerHTML = `
      <button class="back" data-action="close-details">→ كل المناطق</button>
      <h3>${esc(a.name)}</h3>
      <div class="temp-hero ${lvl?.key === "warm" ? "warm" : ""}" style="background:${heatColor(a.temperature)}">
        <span class="big">${a.temperature === null ? "—" : fmt(a.temperature) + "°م"}</span>
        <span>حرارة سطح الأرض</span>
      </div>
      <dl class="detail-rows">
        <div><dt>التصنيف</dt><dd>${esc(classificationAr(a))}</dd></div>
        <div><dt>مؤشر الغطاء النباتي NDVI</dt><dd>${fmt(a.ndvi, 2)}</dd></div>
        <div><dt>أولوية التشجير</dt><dd><span class="badge ${pr.key}">${pr.label}</span></dd></div>
      </dl>
      ${a.priority !== null ? `
        <p class="small muted" style="margin:0">درجة الأولوية: ${fmt(a.priority, 0)} / 100</p>
        <div class="meter"><span style="width:${Math.max(0, Math.min(100, a.priority))}%"></span></div>` : ""}
      <h4 style="margin-top:16px">لماذا هذه المنطقة؟</h4>
      <ul class="reasons">${reasons(a).map((r) => `<li>${esc(r)}</li>`).join("")}</ul>
      ${a.impact ? `<h4 style="margin-top:16px">تأثير التشجير المتوقع</h4><p>${esc(a.impact)}</p>` : ""}`;
  }

  function selectArea(id, fly = true) {
    state.selectedId = id;
    renderAreaList();
    renderDetails();
    state.layers.forEach((layer, lid) => {
      const a = state.areas.find((x) => x.id === lid);
      const s = styleFor(a, lid === id);
      layer.setStyle ? layer.setStyle(s) : layer.eachLayer?.((l) => l.setStyle(s));
    });
    const layer = state.layers.get(id);
    if (layer && fly && state.map) {
      if (layer.getBounds) state.map.fitBounds(layer.getBounds(), { padding: [40, 40], maxZoom: 14 });
      else state.map.setView(layer.getLatLng(), 14);
      layer.openPopup();
    }
    if (window.matchMedia("(max-width: 900px)").matches) {
      $("#side-panel").scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  // ---------- التوصيات ----------
  function renderRecommendations() {
    const list = $("#reco-list");
    const recos = state.areas
      .filter((a) => (a.priority ?? 0) > 0 || isCandidate(a))
      .sort((x, y) => (y.priority ?? 0) - (x.priority ?? 0) || (y.temperature ?? 0) - (x.temperature ?? 0));

    if (!recos.length) {
      list.innerHTML = `<li class="card empty">${state.loaded ? "لا توجد مناطق مرشحة للتشجير في البيانات الحالية." : "لم يتم تحميل البيانات بعد."}</li>`;
      return;
    }
    list.innerHTML = recos.map((a, i) => {
      const pr = priorityLevel(a);
      return `
      <li class="reco" style="border-inline-start-color:${heatColor(a.temperature)}">
        <div class="rank">${fmt(i + 1, 0)}</div>
        <div>
          <h3>${esc(a.name)}</h3>
          <div class="meta">
            <span>🌡️ ${a.temperature === null ? "—" : fmt(a.temperature) + "°م"}</span>
            <span>🌿 NDVI ${fmt(a.ndvi, 2)}</span>
            <span class="badge ${pr.key}">${pr.label}</span>
          </div>
          <ul class="reasons">${reasons(a).map((r) => `<li>${esc(r)}</li>`).join("")}</ul>
          ${a.impact ? `<p><strong>التأثير المتوقع:</strong> ${esc(a.impact)}</p>` : ""}
          <a href="#map" class="btn btn-outline btn-sm" data-show-area="${esc(a.id)}">عرض على الخريطة</a>
        </div>
        <div class="score">
          <div class="num">${a.priority === null ? "—" : fmt(a.priority, 0)}</div>
          <div class="small muted">من 100</div>
        </div>
      </li>`;
    }).join("");

    if (recos.some((a) => a.impact)) $("#impact-note").textContent = "التقديرات المعروضة مأخوذة من بيانات فريق التحليل.";
  }

  function renderAll() {
    renderStats();
    renderLegend();
    renderAreaList();
    renderDetails();
    renderRecommendations();
    renderMapLayers();
  }

  // ---------- التنقل بين الصفحات ----------
  const ROUTES = ["home", "map", "recommendations", "about"];
  function route() {
    const page = ROUTES.includes(location.hash.slice(1)) ? location.hash.slice(1) : "home";
    document.querySelectorAll("[data-page]").forEach((s) => (s.hidden = s.dataset.page !== page));
    document.querySelectorAll("[data-route]").forEach((a) => a.classList.toggle("active", a.dataset.route === page));
    if (page === "map") {
      initMap();
      setTimeout(() => state.map.invalidateSize(), 50); // الخريطة كانت مخفية
    }
    window.scrollTo(0, 0);
  }

  // ---------- رسائل الحالة ----------
  function showToast(msg, isError = false, retry = null) {
    const t = $("#toast");
    t.className = "toast" + (isError ? " error" : "");
    t.innerHTML = `<span>${esc(msg)}</span>${retry ? '<button type="button">إعادة المحاولة</button>' : ""}`;
    if (retry) t.querySelector("button").onclick = retry;
    t.hidden = false;
  }
  const hideToast = () => ($("#toast").hidden = true);

  // ---------- الأحداث ----------
  document.addEventListener("click", (e) => {
    const item = e.target.closest(".area-item");
    if (item) {
      const a = state.areas.find((x) => String(x.id) === item.dataset.id);
      if (a) selectArea(a.id);
      return;
    }
    if (e.target.closest('[data-action="close-details"]')) {
      state.selectedId = null;
      state.map?.closePopup();
      renderAll();
      return;
    }
    const show = e.target.closest("[data-show-area]");
    if (show) {
      const a = state.areas.find((x) => String(x.id) === show.dataset.showArea);
      // ننتظر حتى تُعرض صفحة الخريطة ثم نحدد المنطقة
      setTimeout(() => a && selectArea(a.id), 120);
    }
  });

  window.addEventListener("hashchange", route);
  $("#analysis-map-link").href = CFG.API_BASE + CFG.ANALYSIS_MAP_PATH;

  route();
  loadAreas();
})();
