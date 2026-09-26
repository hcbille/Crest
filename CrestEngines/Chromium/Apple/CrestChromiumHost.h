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

// In-process, main-thread native port. Objects and blocks never enter .NET.
@protocol CrestChromiumEngineHost <NSObject>
// Crest's own UI, which the shell keeps for as long as it runs.
- (void)attachUI:(id<CrestMacUI>)ui NS_SWIFT_NAME(attach(ui:));
// The engine binding creates, loads and closes the pages the core opens,
// reports what they do straight to the core and presents them to the platform.
// What the platform asks of a page directly that no PageRequest carries yet.
// TRANSITIONAL until engine-offered pages and link routing move (WP C (l)): the
// app's own load and a link navigation staged for the page's first load; and
// until the core owns the private window's profile: the regular profile a
// private window's pages derive from.
- (void)loadPage:(NSString *)pageID url:(NSString *)url;
- (BOOL)stageNavigation:(NSString *)token page:(NSString *)pageID url:(NSString *)url;
- (void)setPrivateSourceProfile:(NSString *)profileID;
- (nullable NSView *)viewForPage:(NSString *)pageID;
- (void)setLinkHandlerForPage:(NSString *)pageID
                     handler:(BOOL (^)(NSString *action, NSString *url, NSString *label))handler
    NS_SWIFT_NAME(setLinkHandler(page:handler:));
- (void)setContextMenuHandlerForPage:(NSString *)pageID
    provider:(NSArray<NSDictionary<NSString *, NSString *> *> * (^)(NSString *url, NSString *selection))provider
    action:(BOOL (^)(NSString *identifier, NSString *url, NSString *selection))action
    NS_SWIFT_NAME(setContextMenuHandler(page:provider:action:));
- (void)setProtectedLinkHandlerForPage:(NSString *)pageID
    handler:(CrestDeferredNavigation _Nullable (^)(NSString *url))handler
    NS_SWIFT_NAME(setProtectedLinkHandler(page:handler:));
- (void)setModifiedLinkHandlerForPage:(NSString *)pageID
    handler:(void (^)(NSString *url, NSUInteger modifiers, NSString *token,
        void (^reply)(NSString *decision, CrestDeferredNavigation _Nullable present)))handler
    NS_SWIFT_NAME(setModifiedLinkHandler(page:handler:));
- (void)discardPendingNavigation:(NSString *)token;
- (BOOL)runExtension:(NSString *)extensionID page:(NSString *)pageID
         anchorView:(NSView *)anchorView anchorRect:(NSRect)anchorRect;
// Runs a pinned action with no page open. Only an action carrying its own
// popup document can run: there is no tab to activate, grant host access for or
// inject into. Returns NO for anything else, including a page action.
- (BOOL)runExtension:(NSString *)extensionID profile:(NSString *)profileID window:(NSString *)windowID
          anchorView:(NSView *)anchorView anchorRect:(NSRect)anchorRect
    NS_SWIFT_NAME(runExtension(_:profile:window:anchorView:anchorRect:));
// Extension side panels. A panel is hosted as a Crest split-row card beside
// the page it belongs to: it is not a tab, is never persisted and never syncs.
// `closed` runs when the panel document or its extension host goes away.
- (nullable NSView *)openSidePanel:(NSString *)extensionID page:(NSString *)pageID
                            closed:(void (^)(void))closed
    NS_SWIFT_NAME(openSidePanel(_:page:closed:));
- (void)closeSidePanelForPage:(NSString *)pageID NS_SWIFT_NAME(closeSidePanel(page:));
// Docked DevTools. A Crest window is the user's window, so a docked inspector
// is mounted inside the page card it inspects instead of opening a window of
// its own. The binding presents when the docked frontend changes and answers
// where it goes; this is the frontend's container while an inspector is
// docked on that page, and nil otherwise.
- (nullable NSView *)devToolsViewForPage:(NSString *)pageID NS_SWIFT_NAME(devToolsView(page:));
// chrome.commands. The shortcut's target in the active page's own profile, or
// nil when no enabled extension bound it. A named command has already been
// delivered to its extension and reports `handled`; an `_execute_action`
// binding reports the `action` whose extension the core runs itself, so the
// popup keeps the core's own anchor.
- (nullable NSDictionary<NSString *, id> *)dispatchExtensionShortcut:(NSEvent *)event
    page:(NSString *)pageID NS_SWIFT_NAME(dispatchExtensionShortcut(_:page:));
- (void)setExtensionReview:(void (^)(NSDictionary<NSString *, id> *values, NSWindow *window, void (^reply)(BOOL accept, BOOL withhold)))review;
- (NSString *)engineVersion;
- (BOOL)installExtension:(NSString *)extensionID package:(NSString *)path profile:(NSString *)profileID window:(NSString *)windowID
              completion:(void (^)(BOOL installed, NSString *message))completion;
- (void)disposePages;
- (void)disposePages:(NSArray<NSString *> *)pageIDs windows:(NSArray<NSString *> *)windowIDs
    releaseProfiles:(NSArray<NSString *> *)profileIDs;
- (void)completeQuit;
- (void)prepareToClosePages:(NSArray<NSString *> *)pageIDs windows:(NSArray<NSString *> *)windowIDs
                completion:(void (^)(BOOL allowed))completion NS_SWIFT_NAME(prepareToClose(pages:windows:completion:));
- (void)prepareToQuit:(void (^)(BOOL allowed))completion NS_SWIFT_NAME(prepareToQuit(_:));
- (void)cancelQuitPreparation;
// Declines a system sign-in the core could not place, so the requesting app
// learns at once rather than waiting on a window that will never open.
- (void)cancelAuthenticationSessionForWindow:(NSString *)windowID NS_SWIFT_NAME(cancelAuthenticationSession(window:));
@end
NS_ASSUME_NONNULL_END
