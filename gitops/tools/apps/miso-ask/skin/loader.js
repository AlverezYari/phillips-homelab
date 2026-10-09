// miso-ask skin: the lab's top bar above the chat (MISO Lab · the story · "Ask the data"), so Ask reads as
// one page of the lab with a way back to the game. Styles in custom.css.
(function () {
  var LAB = 'https://miso-lab.phillips-homelab.net/';
  // Inside the lab's own pages (Replay's Ask drawer) the page already has the lab's nav: no bar, a compact layout.
  var embedded = false;
  try { embedded = window.top !== window.self; } catch (e) { embedded = true; }
  if (embedded) { document.documentElement.classList.add('miso-embedded'); return; }
  function bar() {
    if (document.getElementById('miso-bar') || !document.body) return;
    var b = document.createElement('nav');
    b.id = 'miso-bar'; b.setAttribute('aria-label', 'MISO Lab');
    b.innerHTML = '<a class="brand" href="' + LAB + '">MISO Lab</a>' +
      '<a href="' + LAB + '"><span class="step">1</span><span class="lbl">Latest day</span></a>' +
      '<a href="' + LAB + 'play.html"><span class="step">2</span><span class="lbl">Play a day</span></a>' +
      '<a href="' + LAB + 'tour.html"><span class="step">3</span><span class="lbl">How it\'s built</span></a>' +
      '<span class="here"><span class="dot">●</span> Ask the data</span>';
    document.body.insertBefore(b, document.body.firstChild);
    document.body.classList.add('miso-skinned');
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bar); else bar();
  // The app re-renders the body on navigation: put the bar back if it goes.
  new MutationObserver(function () { if (!document.getElementById('miso-bar')) bar(); }).observe(document.documentElement, { childList: true, subtree: false });
})();
