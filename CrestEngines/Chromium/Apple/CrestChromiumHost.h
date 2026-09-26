#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^CrestDeferredNavigation)(void);
// In-process, main-thread native port. Objects and blocks never enter .NET.
@protocol CrestChromiumEngineHost <NSObject>
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
