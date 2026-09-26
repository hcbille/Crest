#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^CrestDeferredNavigation)(void);

// A Chromium feature whose own UI this build never shows. Crest says so in a
// notice instead, in its own words.
typedef NS_ENUM(NSInteger, CrestUnavailableFeature) {
  CrestUnavailableFeatureAutofill,
  CrestUnavailableFeatureAddressAutofill,
  CrestUnavailableFeatureAddressAutofillSignIn,
  CrestUnavailableFeatureAutofillAI,
  CrestUnavailableFeatureAutofillOffers,
  CrestUnavailableFeatureAutofillReauthentication,
  CrestUnavailableFeaturePaymentAutofill,
  CrestUnavailableFeatureVirtualCardEnrollment,
  CrestUnavailableFeatureProfiles,
  CrestUnavailableFeatureEyeDropper,
  CrestUnavailableFeatureCaretBrowsing,
  CrestUnavailableFeaturePrivateBrowsing,
  CrestUnavailableFeatureChromeLabs,
} NS_SWIFT_NAME(UnavailableEngineFeature);

// What one of Chromium's own toasts is about. The message is Chromium's own.
typedef NS_ENUM(NSInteger, CrestEngineNoticeKind) {
  CrestEngineNoticeKindLinkCopied,
  CrestEngineNoticeKindConfirmation,
} NS_SWIFT_NAME(EngineNoticeKind);

// The Crest window a Browser the engine created for itself belongs in, and the
// Space its tabs join.
@protocol CrestEngineWindowPlacement <NSObject>
@property(nonatomic, readonly) NSUUID *window;
@property(nonatomic, readonly) NSUUID *space;
@end

// Crest's own UI, which the Mac shell asks on the main thread for what only
// Crest's windows can answer. The UI framework attaches it when it starts.
NS_SWIFT_UI_ACTOR
@protocol CrestMacUI <NSObject>
// The Crest window named `windowID`, or with none, the window an engine
// surface with no window of its own is shown in.
- (nullable NSWindow *)windowWithID:(nullable NSUUID *)windowID NS_SWIFT_NAME(window(id:));
// Reserves the Crest window for a Browser the engine created for itself and
// names the Space its tabs belong to. Crest is one window: the Browser joins
// the window the person is using, and only a window `chrome.windows.create`
// asked for (`ownWindow`) opens another. None when no Space can host the
// profile's tabs.
- (nullable id<CrestEngineWindowPlacement>)reserveEngineWindowForProfile:(NSUUID *)profileID
                                                              ownWindow:(BOOL)ownWindow
    NS_SWIFT_NAME(reserveEngineWindow(profile:ownWindow:));
// Opens the reserved window just before its first tab is offered.
- (void)presentEngineWindow:(NSUUID *)windowID space:(NSUUID *)spaceID focused:(BOOL)focused
    NS_SWIFT_NAME(presentEngineWindow(_:space:focused:));
// A quit the application asked for; true while Crest finishes it itself.
- (BOOL)deferQuit;
// A Dock click or `Open` with no Crest window.
- (BOOL)reopen;
// A link or document from another app.
- (BOOL)openExternalURLs:(NSArray<NSURL *> *)urls NS_SWIFT_NAME(openExternal(_:));
// An app's system sign-in, in the Quick Window named `windowID`, and its end.
- (BOOL)openAuthenticationSession:(NSURL *)url window:(NSUUID *)windowID
    NS_SWIFT_NAME(openAuthenticationSession(_:window:));
- (void)closeAuthenticationSession:(NSUUID *)windowID NS_SWIFT_NAME(closeAuthenticationSession(window:));
// What the engine's browser window asks of Crest's: a key equivalent web
// content did not take, the location field, a bookmark for the active page,
// translation and tab search.
- (BOOL)handleShortcutEvent:(NSEvent *)event NS_SWIFT_NAME(handleShortcut(_:));
- (void)focusLocation;
- (void)bookmarkActivePage;
- (void)translatePage;
- (void)translateText:(NSString *)text NS_SWIFT_NAME(translate(_:));
- (void)showTabSearch;
- (void)showUnavailableFeature:(CrestUnavailableFeature)feature NS_SWIFT_NAME(showUnavailable(_:));
- (void)showEngineNotice:(NSString *)message kind:(CrestEngineNoticeKind)kind NS_SWIFT_NAME(showEngineNotice(_:kind:));
@end

// What an extension's `chrome.commands` shortcut did. A named command has
// already been delivered to its extension. An `_execute_action` binding names
// the extension whose action Crest runs itself, so its popup keeps the anchor
// a click on the extension's own button would have used.
@protocol CrestExtensionShortcut <NSObject>
@property(nonatomic, readonly, nullable) NSString *actionExtensionID;
@end

// An extension package Chromium verified, which the person approves or
// declines before it installs.
@protocol CrestExtensionReview <NSObject>
@property(nonatomic, readonly) NSString *extensionID;
@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSString *version;
@property(nonatomic, readonly) NSString *summary;
@property(nonatomic, readonly) NSArray<NSString *> *permissions;
@property(nonatomic, readonly, nullable) NSImage *icon;
// Whether the person can withhold the extension's site access, and whether
// approving it withholds that access.
@property(nonatomic, readonly) BOOL canWithholdSiteAccess;
@property(nonatomic, readonly) BOOL withholdsSiteAccess;
@end

// Chromium's Mac shell: what only AppKit does for the engine. It hosts each
// page's view and the views an extension or the inspector puts beside it,
// shows extension popups and the install review, runs system sign-in and
// answers the close and quit preflight. Everything else a page asks goes to
// the engine binding as a PageRequest. In-process and main-thread only;
// objects and blocks never enter .NET.
@protocol CrestMacShell <NSObject>
// Crest's own UI, which the shell keeps for as long as it runs.
- (void)attachUI:(id<CrestMacUI>)ui NS_SWIFT_NAME(attach(ui:));
// TRANSITIONAL until engine-offered pages and link routing move (WP C (l)): the
// app's own load and a link navigation staged for the page's first load; and
// until the core owns the private window's profile: the regular profile a
// private window's pages derive from.
- (void)loadPage:(NSUUID *)pageID url:(NSString *)url;
- (BOOL)stageNavigation:(NSString *)token page:(NSUUID *)pageID url:(NSString *)url;
- (void)setPrivateSourceProfile:(NSUUID *)profileID;
- (nullable NSView *)viewForPage:(NSUUID *)pageID;
// TRANSITIONAL until link questions travel as presentations (WP C (l)).
- (void)setLinkHandlerForPage:(NSUUID *)pageID
                     handler:(BOOL (^)(NSString *action, NSString *url, NSString *label))handler
    NS_SWIFT_NAME(setLinkHandler(page:handler:));
- (void)setContextMenuHandlerForPage:(NSUUID *)pageID
    provider:(NSArray<NSDictionary<NSString *, NSString *> *> * (^)(NSString *url, NSString *selection))provider
    action:(BOOL (^)(NSString *identifier, NSString *url, NSString *selection))action
    NS_SWIFT_NAME(setContextMenuHandler(page:provider:action:));
- (void)setProtectedLinkHandlerForPage:(NSUUID *)pageID
    handler:(CrestDeferredNavigation _Nullable (^)(NSString *url))handler
    NS_SWIFT_NAME(setProtectedLinkHandler(page:handler:));
- (void)setModifiedLinkHandlerForPage:(NSUUID *)pageID
    handler:(void (^)(NSString *url, NSUInteger modifiers, NSString *token,
        void (^reply)(NSString *decision, CrestDeferredNavigation _Nullable present)))handler
    NS_SWIFT_NAME(setModifiedLinkHandler(page:handler:));
- (void)discardPendingNavigation:(NSString *)token;
- (BOOL)runExtension:(NSString *)extensionID page:(NSUUID *)pageID
         anchorView:(NSView *)anchorView anchorRect:(NSRect)anchorRect;
// Runs a pinned action with no page open. Only an action carrying its own
// popup document can run: there is no tab to activate, grant host access for or
// inject into. Returns NO for anything else, including a page action.
- (BOOL)runExtension:(NSString *)extensionID profile:(NSUUID *)profileID window:(NSUUID *)windowID
          anchorView:(NSView *)anchorView anchorRect:(NSRect)anchorRect
    NS_SWIFT_NAME(runExtension(_:profile:window:anchorView:anchorRect:));
// Extension side panels. A panel is hosted as a Crest split-row card beside
// the page it belongs to: it is not a tab, is never persisted and never syncs.
// `closed` runs when the panel document or its extension host goes away.
- (nullable NSView *)openSidePanel:(NSString *)extensionID page:(NSUUID *)pageID
                            closed:(void (^)(void))closed
    NS_SWIFT_NAME(openSidePanel(_:page:closed:));
- (void)closeSidePanelForPage:(NSUUID *)pageID NS_SWIFT_NAME(closeSidePanel(page:));
// Docked DevTools. A Crest window is the user's window, so a docked inspector
// is mounted inside the page card it inspects instead of opening a window of
// its own. The binding presents when the docked frontend changes and answers
// where it goes; this is the frontend's container while an inspector is
// docked on that page, and nil otherwise.
- (nullable NSView *)devToolsViewForPage:(NSUUID *)pageID NS_SWIFT_NAME(devToolsView(page:));
// chrome.commands: what the shortcut did in the active page's own profile, or
// nil when no enabled extension bound it.
- (nullable id<CrestExtensionShortcut>)dispatchExtensionShortcut:(NSEvent *)event
    page:(NSUUID *)pageID NS_SWIFT_NAME(dispatchExtensionShortcut(_:page:));
- (void)setExtensionReview:(void (^)(id<CrestExtensionReview> review, NSWindow *window,
                                     void (^reply)(BOOL accept, BOOL withhold)))review;
- (NSString *)engineVersion;
- (BOOL)installExtension:(NSString *)extensionID package:(NSString *)path profile:(NSUUID *)profileID
                  window:(NSUUID *)windowID completion:(void (^)(BOOL installed, NSString *message))completion;
- (void)disposePages;
- (void)disposePages:(NSArray<NSUUID *> *)pageIDs windows:(NSArray<NSUUID *> *)windowIDs
    releaseProfiles:(NSArray<NSUUID *> *)profileIDs;
- (void)completeQuit;
- (void)prepareToClosePages:(NSArray<NSUUID *> *)pageIDs windows:(NSArray<NSUUID *> *)windowIDs
                completion:(void (^)(BOOL allowed))completion NS_SWIFT_NAME(prepareToClose(pages:windows:completion:));
- (void)prepareToQuit:(void (^)(BOOL allowed))completion NS_SWIFT_NAME(prepareToQuit(_:));
- (void)cancelQuitPreparation;
// Declines a system sign-in the core could not place, so the requesting app
// learns at once rather than waiting on a window that will never open.
- (void)cancelAuthenticationSessionForWindow:(NSUUID *)windowID NS_SWIFT_NAME(cancelAuthenticationSession(window:));
@end
NS_ASSUME_NONNULL_END
