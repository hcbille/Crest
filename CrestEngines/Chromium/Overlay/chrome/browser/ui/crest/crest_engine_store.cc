#include "chrome/browser/ui/crest/crest_engine_store.h"

#include <string_view>
#include <vector>

#include "base/json/json_writer.h"
#include "base/strings/string_split.h"
#include "base/strings/string_util.h"
#include "base/strings/utf_string_conversions.h"
#include "base/values.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/common/chrome_isolated_world_ids.h"
#include "content/public/browser/navigation_handle.h"
#include "content/public/browser/render_frame_host.h"
#include "content/public/browser/web_contents.h"
#include "extensions/browser/extension_registry.h"
#include "url/gurl.h"
#include "url/url_constants.h"

namespace crest {

namespace {

bool IsWebStoreURL(const GURL& url) {
  return url.SchemeIs(url::kHttpsScheme) && url.host() == "chromewebstore.google.com";
}

// The extension a store detail URL names, or an empty string for any other
// store page. Chrome Web Store identifiers are 32 characters from a-p.
std::string WebStoreExtensionID(const GURL& url) {
  if (!IsWebStoreURL(url)) return std::string();
  const std::string_view path = url.path();
  std::vector<std::string_view> parts = base::SplitStringPiece(
      path, "/", base::TRIM_WHITESPACE, base::SPLIT_WANT_NONEMPTY);
  if (parts.size() < 2 || parts.front() != "detail") return std::string();
  std::string_view candidate = parts.back();
  if (candidate.size() != 32) return std::string();
  for (char character : candidate)
    if (character < 'a' || character > 'p') return std::string();
  return std::string(candidate);
}

// The isolated-world script. It uses DOM and CSSOM APIs only: the store's
// content policy rejects stylesheets and inline style attributes Crest would
// add to the markup, but script-driven property changes are not markup.
const char* CrestStoreScript() {
  return R"JS((function() {
  if (window.__crestStore) { window.__crestStore.render(); return; }
  var labels = { install: 'Add to Crest', installed: 'Added to Crest',
                 remove: 'Remove from Crest', busy: 'Installing…' };
  var state = { id: '', installed: false, busy: false };
  var adopted = null, hovering = false, pending = false;
  function detailID() {
    var match = /\/detail\/(?:[^\/]+\/)?([a-p]{32})(?:\/|$)/.exec(location.pathname);
    return match ? match[1] : '';
  }
  function label(button) { return button.querySelector('span[jsname="V67aGc"]') || button; }
  function text(node) { return (node.textContent || '').replace(/\s+/g, ' ').trim(); }
  // The store keeps the listing it navigated away from in the document and
  // only hides it, so anything that is not actually rendered is stale.
  function shown(element) {
    if (!element || !element.isConnected) return false;
    var rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }
  function installLabel(value) {
    return /^(add to|added to|remove from) (chrome|crest)$/i.test(value) || value === labels.busy;
  }
  // The listing's own install button: the one in the section that carries the
  // extension's title, so a related listing's button is never adopted.
  function locate() {
    if (shown(adopted)) return adopted;
    adopted = null; hovering = false;
    var headings = document.querySelectorAll('h1'), scope = null;
    for (var heading = 0; heading < headings.length; heading++) {
      if (!shown(headings[heading])) continue;
      scope = headings[heading].closest('section');
      break;
    }
    var buttons = (scope || document).querySelectorAll('button');
    for (var index = 0; index < buttons.length; index++) {
      var button = buttons[index];
      if (!shown(button) || !installLabel(text(label(button)))) continue;
      adopted = button;
      button.addEventListener('pointerenter', function() { hovering = true; render(); });
      button.addEventListener('pointerleave', function() { hovering = false; render(); });
      button.addEventListener('focus', function() { hovering = true; render(); });
      button.addEventListener('blur', function() { hovering = false; render(); });
      return button;
    }
    return null;
  }
  // The store's desktop layout keeps a minimum width wider than a Crest page
  // card, which pushes the listing and its install button past the card's
  // edge. Releasing that minimum lets the store use its own narrow layout.
  function relax() {
    // The store keeps the listing it navigated away from, so each document can
    // hold more than one of these; every one of them has to be released.
    var elements = [document.body].concat(
        Array.prototype.slice.call(document.querySelectorAll('header, main')));
    for (var index = 0; index < elements.length; index++) {
      var element = elements[index];
      if (!element) continue;
      var minimum = parseFloat(getComputedStyle(element).minWidth);
      if (minimum > 0 && minimum > window.innerWidth) element.style.minWidth = 'auto';
    }
  }
  // Crest installs extensions itself, so the store's prompts to switch to
  // Chrome are noise. Each prompt is found from its own wording and hidden at
  // the outermost element that still says nothing else, so the listing around
  // it is never affected.
  function hidePrompt(pattern, limit) {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    var node;
    while ((node = walker.nextNode())) {
      if (!pattern.test(node.nodeValue || '')) continue;
      var element = node.parentElement, box = null;
      while (element && element !== document.body && text(element).length <= limit) {
        box = element;
        element = element.parentElement;
      }
      // A prompt the store re-rendered leaves the hidden original behind, so
      // a match that is already hidden is not the one to act on.
      if (!box || box.style.display === 'none') continue;
      box.style.display = 'none';
      return;
    }
  }
  var swept = 0, sweeping = 0;
  function hidePrompts() {
    // A prompt can be the last thing the store adds, so a suppressed sweep is
    // always retried rather than dropped.
    var waiting = 500 - (Date.now() - swept);
    if (waiting > 0) {
      if (!sweeping) sweeping = setTimeout(function() { sweeping = 0; hidePrompts(); }, waiting);
      return;
    }
    swept = Date.now();
    hidePrompt(/switch to chrome to install/i, 140);
    hidePrompt(/switch to chrome\?/i, 260);
  }
  function render() {
    relax();
    hidePrompts();
    var button = locate();
    if (!button) return;
    var wanted = state.busy ? labels.busy
        : (state.installed ? (hovering ? labels.remove : labels.installed) : labels.install);
    var span = label(button);
    if (text(span) !== wanted) span.textContent = wanted;
    if (button.disabled) button.disabled = false;
    button.removeAttribute('disabled');
    button.setAttribute('aria-disabled', state.busy ? 'true' : 'false');
    button.setAttribute('aria-label', wanted);
  }
  function schedule() {
    if (pending) return;
    pending = true;
    requestAnimationFrame(function() { pending = false; render(); });
  }
  // The core owns the install review, so the click never reaches the store's
  // own handler. The request names the extension the page itself is showing
  // and the core checks that name again before it downloads anything.
  function request() {
    var id = detailID();
    if (!id || state.busy) return;
    var command = state.installed ? 'crest-remove' : 'crest-install';
    if (!state.installed) { state.busy = true; render(); }
    history.replaceState(history.state, '',
        location.pathname + location.search + '#' + command + '=' + id);
  }
  document.addEventListener('click', function(event) {
    var button = locate();
    var target = event.target;
    if (!button || !target || !(target === button || (target.nodeType === 1 && button.contains(target)))) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    request();
  }, true);
  window.addEventListener('resize', function() { schedule(); });
  new MutationObserver(schedule).observe(document.documentElement,
      { childList: true, subtree: true, characterData: true });
  window.__crestStore = {
    render: render,
    apply: function(next) {
      state.id = next && typeof next.id === 'string' ? next.id : '';
      state.installed = !!(next && next.installed);
      state.busy = false;
      if (!adopted || !adopted.isConnected) { adopted = null; }
      render();
    }
  };
  render();
})();)JS";
}

}  // namespace

PageStore::PageStore(content::WebContents* contents, const engine::Guid& page, Present present)
    : contents_(contents), page_(page), present_(std::move(present)) {}

PageStore::~PageStore() = default;

void PageStore::DocumentAvailable() {
  if (!Frame()) {
    return;
  }
  Run(CrestStoreScript());
  Refresh();
}

bool PageStore::Committed(const GURL& url) {
  if (Consume(url)) {
    return true;
  }
  // The store is a single-page application: a listing change keeps the
  // document, so the script stays and only its state has to be refreshed.
  // Restoring the listing's own address is Crest's own edit, not a change of
  // listing, so it must not reset a request that is still open.
  if (request_open_) {
    request_open_ = false;
  } else {
    Refresh();
  }
  return false;
}

void PageStore::RequestFinished() {
  request_open_ = false;
  Refresh();
}

void PageStore::Refresh() {
  auto* frame = Frame();
  if (!frame) {
    return;
  }
  const std::string id = WebStoreExtensionID(frame->GetLastCommittedURL());
  bool installed = false;
  if (!id.empty()) {
    auto* registry = extensions::ExtensionRegistry::Get(contents_->GetBrowserContext());
    installed = registry && registry->GetInstalledExtension(id) != nullptr;
  }
  auto json = base::WriteJson(base::DictValue().Set("id", id).Set("installed", installed));
  if (!json) {
    return;
  }
  Run("window.__crestStore && window.__crestStore.apply(" + *json + ");");
}

// Regular profiles only: a private window must not change a Space's
// persistent extension state, so its store pages keep the engine's own
// behaviour.
content::RenderFrameHost* PageStore::Frame() const {
  if (contents_->GetBrowserContext()->IsOffTheRecord()) {
    return nullptr;
  }
  auto* frame = contents_->GetPrimaryMainFrame();
  if (!frame || !IsWebStoreURL(frame->GetLastCommittedURL())) {
    return nullptr;
  }
  return frame;
}

void PageStore::Run(const std::string& script) {
  if (auto* frame = Frame()) {
    frame->ExecuteJavaScriptInIsolatedWorld(base::UTF8ToUTF16(script), {}, ISOLATED_WORLD_ID_CHROME_INTERNAL);
  }
}

// A request the injected script wrote into the listing's own URL fragment.
// The extension it names has to be the one the page is showing, so a store
// page cannot ask Crest to install anything else, and Crest still runs its
// own install review before the engine verifies the package.
bool PageStore::Consume(const GURL& url) {
  if (!Frame() || !url.has_ref()) {
    return false;
  }
  const std::string_view ref = url.ref();
  constexpr std::string_view kInstall = "crest-install=";
  constexpr std::string_view kRemove = "crest-remove=";
  bool removes = false;
  std::string requested;
  if (base::StartsWith(ref, kInstall)) {
    requested = std::string(ref.substr(kInstall.size()));
  } else if (base::StartsWith(ref, kRemove)) {
    removes = true;
    requested = std::string(ref.substr(kRemove.size()));
  } else {
    return false;
  }
  // Leave the listing's own address in place; the fragment is a message.
  Run("history.replaceState(history.state, '', location.pathname + location.search);");
  const std::string expected = WebStoreExtensionID(url);
  if (expected.empty() || requested != expected) {
    Refresh();
    return true;
  }
  // Crest owns the request now: the button keeps its own progress label
  // until the review Crest presents finishes.
  request_open_ = true;
  if (removes) {
    present_.Run(engine::StoreRemovalRequested{.page_id = page_, .extension_id = expected});
  } else {
    present_.Run(engine::StoreInstallRequested{.page_id = page_, .extension_id = expected});
  }
  return true;
}

}  // namespace crest
