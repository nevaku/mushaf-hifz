// Page-specific QCF glyph fonts for the Mushaf view. The API's code_v2 field carries QPC V2
// glyph codes (Private Use Area) that only render correctly under the exact font built for that
// page — a page's glyphs are positioned for that page's printed line layout, so another page's
// font yields misplaced/overlapping ink. So we load ONE font per opened page (not all 604 up
// front): QCF_P<NNN>.woff2 for the page being rendered, wait for it, then paint the page with it.
//
// Fonts live in fonts/qcf/ (offline-safe, bundled into the APK by build/make-www.js). If a page
// file isn't there yet (e.g. a fresh checkout before build/download-qcf-fonts.ps1 has run), we
// fall back to the identical V2 font on Quran.com's CDN. A load that fails both ways rejects so
// the renderer can fall back to the plain Unicode text instead of blanks.
//
// Family naming ("QCFPage001") matches the CSS hook app.js sets as --qcf-page-font, e.g.
//   .mushaf-page.qcf-mode .word { font-family: var(--qcf-page-font), serif; }
(function (window) {
  "use strict";

  var LOCAL_DIR = "fonts/qcf/";
  var CDN_BASE = "https://quran.com/fonts/quran/hafs/v2/woff2/p";

  var fontLoads = Object.create(null); // pageNo -> Promise<familyName>
  var loaded = Object.create(null);    // pageNo -> true once registered with document.fonts

  function pageTag(pageNo) {
    return String(pageNo).padStart(3, "0");
  }

  function familyFor(pageNo) {
    return "QCFPage" + pageTag(pageNo);
  }

  function loadUrl(family, url) {
    return new FontFace(family, 'url("' + url + '")').load();
  }

  // Resolves the page's font-family name once its face is loaded and registered, or rejects if
  // neither the local file nor the CDN copy could be loaded. Concurrent calls for the same page
  // share a single in-flight promise; a failure is NOT cached (a later attempt can retry).
  function loadQcfFont(pageNo) {
    var n = parseInt(pageNo, 10);
    if (!(n >= 1)) return Promise.reject(new Error("invalid page " + pageNo));
    var tag = pageTag(n);
    if (fontLoads[tag]) return fontLoads[tag];

    var family = familyFor(n);
    if (typeof FontFace === "undefined" || !document.fonts) {
      return Promise.reject(new Error("FontFace API unavailable"));
    }

    var promise = loadUrl(family, LOCAL_DIR + "QCF_P" + tag + ".woff2")
      .catch(function () { return loadUrl(family, CDN_BASE + n + ".woff2"); })
      .then(function (loadedFont) {
        document.fonts.add(loadedFont);
        loaded[tag] = true;
        return family;
      })
      .catch(function (err) {
        delete fontLoads[tag]; // never cache a failure — allow a retry on the next render
        throw err;
      });

    fontLoads[tag] = promise;
    return promise;
  }

  // true once this page's font has been registered (so a cached re-render can paint it without
  // waiting a microtask on a promise that's already resolved — no flash of the previous page)
  function isLoaded(pageNo) {
    return !!loaded[pageTag(pageNo)];
  }

  window.QcfFont = { load: loadQcfFont, familyFor: familyFor, isLoaded: isLoaded };
})(window);
