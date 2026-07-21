/* Home language toggle (IT / EN).
   Picks the language from a saved choice (localStorage) or, on first visit,
   from the browser/OS language (navigator.language). A manual click wins and
   is remembered. With JS disabled, both language blocks stay visible.
   Scoped to the homepage: this script is only loaded there (extend_footer.html). */
(function () {
  "use strict";
  var LANGS = ["it", "en"];
  var STORE = "home-lang";

  function detect() {
    try {
      var saved = localStorage.getItem(STORE);
      if (saved && LANGS.indexOf(saved) > -1) return saved;
    } catch (e) { /* localStorage may be unavailable */ }
    var nav = (navigator.language || navigator.userLanguage || "en").toLowerCase();
    return nav.indexOf("it") === 0 ? "it" : "en";
  }

  function apply(lang) {
    document.querySelectorAll(".profile_inner .lang").forEach(function (el) {
      el.style.display = el.classList.contains("lang-" + lang) ? "" : "none";
    });
    document.querySelectorAll(".lang-toggle button").forEach(function (b) {
      var on = b.getAttribute("data-lang") === lang;
      b.classList.toggle("active", on);
      b.setAttribute("aria-pressed", on ? "true" : "false");
    });
  }

  function build() {
    var blocks = document.querySelectorAll(".profile_inner .lang");
    if (!blocks.length) return; // markup not present → leave as-is
    var anchor = document.querySelector(".profile_inner span");
    if (!anchor) return;

    var nav = document.createElement("div");
    nav.className = "lang-toggle";
    nav.setAttribute("role", "group");
    nav.setAttribute("aria-label", "Language");
    LANGS.forEach(function (l) {
      var b = document.createElement("button");
      b.type = "button";
      b.setAttribute("data-lang", l);
      b.textContent = l.toUpperCase();
      b.addEventListener("click", function () {
        try { localStorage.setItem(STORE, l); } catch (e) {}
        apply(l);
      });
      nav.appendChild(b);
    });
    anchor.parentNode.insertBefore(nav, anchor);

    apply(detect());
  }

  if (document.readyState !== "loading") build();
  else document.addEventListener("DOMContentLoaded", build);
})();
