# Engine abstraction status

Crest has one engine contract with two bindings, WebKit and Chromium, and keeps
every browser rule in the portable core. This document records what each work
package has done and what it still lacks. Read [ControlPlane.md](ControlPlane.md)
for how the design works, and [CoreArchitecture.md](CoreArchitecture.md) for
the target, which wins where they differ. Follow `AGENTS.md` for versioning,
release notes and tests.

Items marked **TRANSITIONAL** name the package that removes them.

## Ownership

| Layer | Owns | Never owns |
| --- | --- | --- |
| Portable core (`CrestCore`) | Every piece of browser state and every rule that must behave the same on both engines and both platforms: sessions, windows and what each shows, pages and their live state, prompts, downloads, site permissions, credential policy, search and completion, import and export, setup, shortcuts, launch policy, behavior preferences, engine registrations and per-site engine choices, storage and sync | Rendering, input, scrolling, compositing, engine handles, image bytes, OS services |
| Engine bindings (`CrestEngines/Chromium`, `WebKitEngineBinding` and the WebKit page code in `CrestShared` and `CrestMac`) | Page creation and disposal, loads, engine navigation history, find, zoom, capture, printing, export, DevTools, extensions, download transfer, website data and cookie stores, reporting what happened to the core | Deciding browser rules; changing browser state other than by reporting events |
| Shared Swift (`CrestShared`, `CrestMac`, `CrestMobile`) | Views, layout, animation, presentation of prompts and notices, native windows and cards, OS services (Keychain, CloudKit transport, notification delivery, LaunchServices) | Engine types or `#if CREST_CHROMIUM_HOST` outside the engine code; second copies of core rules |

Scrolling, pointer input, compositing, focus and page zoom stay inside the
engine and never cross the core boundary. A core intent owns every saved or
shared transition, and a binding reports what the engine did.

Rules every package keeps:

- A Space is one profile on every engine. No path may share a profile across
  Spaces, or create a page, transfer, export or network request for a locked
  Space without a grant. The core gate covers intents and borrowing; the
  presentation layer must not build content for a locked Space.
- A private window is incognito on every engine. Its profile is new each time
  private browsing opens, shares nothing with any Space, runs no extension a
  person installed, and is destroyed with everything in it when the window
  closes.
- Crest is a single-window app. New windows appear only from a user action or
  an explicit extension `windows.create`. DevTools, popups and side panels dock
  inside the Crest window.
- Capability declarations in `BrowserEngineRegistration` describe what the
  binding really does. The core offers what the default engine supports and
  what each engine a page is open on supports, and the page's own engine
  enables it. UI never gates on build flags.
- Unsupported features have explicit product behavior. Reader, whole-page
  translation, built-in content blocking and protected media are unavailable
  on Chromium by decision; a page that needs protected media moves to WebKit.
  Selection translation works on both engines.

## Current state

The core owns the session, the device and the pages on every shipping target.
On macOS the Chromium composition (`CrestChromiumUIProduct`, packaged by
`package-chromium-host.py --product`) is the default download on the
experimental update channel, with WebKit registered beside it. The WebKit
`Crest` target is published as the alternate desktop build, and `CrestMobile`
runs WebKit on iPhone and iPad.

Chromium's binding is portable C++ inside the engine, keeps Chromium's
`Browser`s and reports to the core directly; its Mac shell only makes and
hosts windows, views, popups and system sign-in. WebKit's
binding is Swift, shared by macOS and iOS. `BrowserPage`
(`CrestMac/Infrastructure/Pages`) holds an `any BrowserPageEngineAdapter` and
names no engine type. `MobileBrowserPage` is typed over WebKit by design,
since iPhone and iPad run only WebKit. `project.yml` selects each composition's entry point,
engine registration and engine-contributed views by file, and no Swift outside
`CrestEngines` tests `CREST_CHROMIUM_HOST`.

One shared page host, `BrowserPageHost`, keeps each workspace's pages on the
Mac, iPhone and iPad, and one shared page owner, `BrowserPageOwner`, does the
rest of the work both platforms' pages have in common, including hosting the
pages the core opens itself. `BrowserPagePool` and `MobileBrowserPageStore`
keep only presentation and each platform's own commands. WebKit's binding
keeps each profile's website data store and compiles the content rules its
pages are built with.

Engine glue, the page hosts and the tests read the core's read model; no Swift
copy of the session remains.

## Work packages

### WP0. Manual smoke of Chromium-owned surfaces. Remaining

Nobody has recorded the checklist yet. Run it in a review package and mark
each item as works, wrong window or missing: `alert`, `confirm` and `prompt`;
`<input type=file>` with single and multiple selection; a Basic-auth URL;
`<input type=color>`; fullscreen video and Escape; a site notification's
permission and delivery; the PiP button; a protected video that moves to
WebKit, and Move Back.

What the code does today:

- Script dialogs, before-unload, and HTTP Basic and Digest challenges are
  questions the binding raises with the core, which the page's host presents.
- Page fullscreen reports its state to the shared shell, which shows the video
  without browser chrome and restores the shell on Escape.
- The host has no hook for the file chooser or the color picker, so both use
  Chromium's own engine surfaces.
- Notifications use Chromium's own delivery path.

### WP1. Dead-code sweep. Done

The value-level session edit surface, its exports, the retired kernel and the
Swift rule copies the core replaced are gone. Launch cleanup and retention run
as the core's `SweepExpiredRecords` intent.

### WP2. Page port. Done, with gaps

Done:

- **Content scripts.** Crest's bridges run on Chromium in an isolated world
  the page cannot reach; WebKit installs its own through its user content
  controller. Link hover, user activity, blocked popups, media sessions and
  favicons arrive from Chromium as engine presentations.
- **Page split.** The page and its engine-neutral extensions live in
  `CrestMac/Infrastructure/Pages` and `CrestShared/Infrastructure/Pages`. The
  engine builds each page, and the pool wraps what it built in the page's
  adapter. Back and forward menus read the engine's history on both engines.
- **Zoom, find and navigation.** The page applies each Space's default zoom
  above the engine. Both engines wrap find; Chromium reports the match total.
- **Popups.** Chromium relays blocked popups and applies each Space's
  automatic-popup decision; allowing the site opens the popups the blocker
  held back.
- **Downloads.** Both engines run their downloads as the engine's own and
  report them to the core's ledger.

Remaining, TRANSITIONAL:

- `CredentialContentBridge.swift` in `CrestShared/Infrastructure/Credentials`
  still imports WebKit to install the WebKit credential bridge.
- The transient page lease carries WebKit content-rule lists.

Remaining otherwise:

- Focus restoration on Chromium relies on the engine's responder chain;
  nobody has verified it end to end.
- Quick Window and setup windows have no extension side-panel host.

### WP3. Security indicator, certificates and HTTP auth. Done, with one gap

Each page's live state carries an engine-neutral `PageSecurity`, whose members
carry the title, symbol and detail Site Controls shows. Chromium reports it in
every snapshot; WebKit derives it from the scheme, mixed content, the trust
result and any override. Basic and Digest authentication are questions the
core asks through the page's host on both engines.

Remaining: certificate errors on Chromium show Chromium's own interstitial,
and proceeding is the engine profile's decision, as its registration declares.
A proceed-anyway owned by Crest, with the override kept by the core, is not
built.

### WP4. Credentials on Chromium. Done

The credential bridge runs through the content-script channel on Chromium.
Capture, fill, save and recency rules are core queries that carry no
password. The host turns Chromium's password manager off for every page, so
its bubbles never appear. iCloud Passwords runs through its extension, and
passkeys go through the system sheet. Password files are read, planned and
written by the core without keeping any secret (see ControlPlane.md).

### WP5. Site permissions, geolocation and notifications. Done, with gaps

Permission choices are records in the core's device store, changed by typed
intents and answered by the `SiteDecision` and `CaptureDecision` queries.
Permission requests are questions the binding raises with the core, which
answers from the Space's choices or asks the person. Chromium receives
decisions as content settings; WebKit applies them through its delegates, and
withdrawing a camera or microphone grant ends capture.

Remaining, as the Chromium registration declares:

- The host has no command to stop live camera, microphone or location use.
  Revocation relies on Chromium ending capture once the setting blocks it.
- Chromium delivers web notifications itself. Delivery through Crest,
  source-tab activation and withdrawal after revocation need a host hook.

### WP6. Capability truth and UI hygiene. Done

- The core publishes the registered engines and what the device offers as
  `EnginesChanged`. Menus, the launcher, settings and the shortcut settings
  offer that, and the page a command acts on enables it through its own
  engine: on the Chromium product, Reader appears once a WebKit page is open
  and stays dimmed on Chromium pages.
- When content blocking is unavailable, the Privacy pane says that blocking
  comes from the extensions the person installs.
- Archives follow the engine: `.webarchive` on WebKit, `.mhtml` on Chromium.
- Internal pages follow the `internal-pages` capability.
- Every declared capability gates UI or services, or belongs to
  `EngineCapability.Required`.

### WP7. WebKit symmetry. Done

WebKit reports each page's media activity to the core as it changes,
including its real Picture in Picture activity, so residency never asks pages
first. A page it closes keeping its state hands the core its history, which
the tab's next page restores, as Chromium's do. It stages Peek navigation with
the source request and website data store, and prepares a page close through
WebKit's before-unload path. A staged Peek carries the URL
and referrer only, because WebKit does not expose the initiating frame's
security context to a second page; the registration declares that limit.
WebKit extensions are retired, and the WebKit registration declares
`extensions` unavailable.

### WP8. Core extraction of the rule aggregates. Done, with one leftover

Every aggregate is core domain and application code with focused tests,
reached through typed intents and queries. Queries that need no session are
answered without an app (`crest_core_answer`): address and page comparisons,
translation choices, import discovery, launch isolation, branding
normalization, page presentation, external links and local documents, scheme
handling, authentication handling and labels, fixture server trust, media
session arbitration, secure origins, notification requests, blocked popups
and automatic downloads.

| Aggregate | Core surface |
| --- | --- |
| Downloads | The download intents and changes, and the `DownloadProgress` and `DownloadRisk` queries; the engine download events and commands |
| Credentials and passkeys | The capture, fill, save-check, recency, save-match, save, strong-password, passkey and system-password queries, which carry no password; `CredentialImportPreview`, `PasswordImportPreview` and `CredentialExport`, which carry passwords the core never keeps |
| Site permissions | The permission intents and the `SiteDecision` and `CaptureDecision` queries |
| Search, completion and the palette | `SearchProvider`, the search engine intents, `PaletteSuggestions` |
| Windows, sidebar and setup | The window intents, the sidebar outline and drop targets, `SelectionPreview`, the setup draft and flow intents and `FinishSetup` |
| Shortcuts, launch and media | The shortcut intents and `NumberedSelections`; `LaunchIsolation` and the launch plan; media session arbitration |
| Behavior preferences | The session's `appPreferences` record behind `SetAppPreferences`, `SetTranslationRule` and `ImportAppPreferences` |
| Links and Quick Window | `ExternalLinkRoute`, `QuickWindowSite`, `LinkNavigation` and the link preference intents |
| Engines | `EnginesChanged`, `ChooseSiteEngine`, `RehostPage`, `ProtectedMediaUnavailable` |

These stay in Swift by design: heraldry vocabulary and composition, favicon
palette extraction, sidebar widgets, Peek motion and presentation phases,
tear-off placement geometry, drag geometry and default-browser prompt cadence.

### WP9. Verification and release gates. Partly done

Done:

- Builds: `Crest`, `CrestChromiumUI`, `CrestChromiumUIProduct` and
  `CrestMobile`; `dotnet test` and `lint-dotnet.sh`; the C and C++ ABI checks.
- Review packaging for runtime checks:
  `Scripts/control-plane/apply-chromium-host.py`, then
  `build-chromium-baseline.py`, then `package-chromium-host.py` in review mode
  with a throwaway user-data directory. Never launch the unbranded Chromium
  build directly, because its keychain item prompts.
- Product packaging: `.github/workflows/experimental-release.yml` downloads
  the prebuilt engine, packages `CrestChromiumUIProduct`, signs it with Crest's
  entitlements and embedded provisioning profile, and notarizes both apps.
  Never use the review entitlements file for the product: it turns on the app
  sandbox and would strand installed data.
- The Safe Storage keychain item name must not change. A rename rotates the
  encryption key and resets Chromium's tracked preferences.

Remaining:

- The WP0 manual smoke checklist.
- Which streaming services play in a WebKit page inside Crest, and whether
  some need Safari's user agent.
- Cross-engine sync convergence between the Chromium Mac product and an
  iPhone through the isolated CloudKit review zone, verified from records as
  well as UI.
- The upgrade on a physical device, and a sync run against a real account with
  installed Spaces.
- Manual product review of every flow on both engines before early user
  testing.

### WP10. Multiple engines. Done

- Engines in the read model, the `protected-media` capability, and offering by
  the default engine and the engines that host pages.
- Per-site engine choices in the device store, consulted when a tab's page
  opens, and a restore state kept per engine.
- `RehostPage`, the moves toward a site's chosen engine, and the Site Controls
  engine row.
- The protected media fallback with its notice and Move Back, and Chromium's
  report of a missing Widevine or PlayReady key system.

A moved page takes its new engine's adapter and view in place, and WebKit's
binding builds a page no owner asked for when the core moves one to it, from
its own stores and rules.
Deleting a Space and clearing a site's data reach every registered engine,
started or not.

## Deferred

The product owner has deferred these:

- A Crest color picker for `<input type=color>`. Chromium's own picker is used.
- A Crest popups UI beyond the blocked-popup relay and Site Controls.
- A Crest presentation for JavaScript alerts beyond the shared dialog
  presenter.
- System Picture in Picture on Chromium. Chromium's video PiP uses its own
  Views window; a system PiP needs a video-frame bridge from Chromium's video
  surface. Do not use macOS's private PIP framework without a separate product
  decision.

## Future merge work

The branch stays on the experimental update channel, and no merge is
scheduled. When it merges, `release.yml` must publish the Chromium product as
the default Mac download with WebKit as the alternate, each with its own
development and stable feeds, and `project.yml`'s default update channel must
move from `experimental` to `development`.

## Ownership decision guide

Use this when a new feature arrives:

1. Must the outcome be identical on WebKit and Chromium, or on Mac and iPhone?
   Then it is a core rule: an intent when it changes state, a query when it is
   an answer, and a change or read-model value for what the UI shows.
2. Is it rendering, input, scrolling, compositing, an engine handle or a
   platform service? Then it is binding or platform work. Declare a capability
   in `BrowserEngineRegistration` if an engine may lack it.
3. Is it layout, animation or presentation state? Then it is shared Swift, and
   it gates on what the core offers and the page's engine supports, never on
   engine `#if` flags.
4. Does it touch a locked Space? The core gate must reject it, and the
   presentation layer must not build its content.
5. Does it open a window? Only from a user action or an explicit extension
   request. Otherwise it reuses the current window or docks inside it.
