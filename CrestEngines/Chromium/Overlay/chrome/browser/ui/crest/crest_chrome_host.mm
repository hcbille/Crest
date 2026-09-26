#import <AuthenticationServices/AuthenticationServices.h>
#import <Cocoa/Cocoa.h>
#import "CrestChromiumHost.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <cmath>
#include <memory>
#include <string>
#include <set>
#include <vector>
#include "base/check.h"
#include "base/apple/bridging.h"
#include "base/apple/foundation_util.h"
#include "base/apple/scoped_cftyperef.h"
#include "base/pickle.h"
#include "base/json/json_reader.h"
#include "base/timer/timer.h"
#include "content/public/browser/devtools_agent_host.h"
#include "content/public/browser/devtools_agent_host_client.h"
#include "base/functional/bind.h"
#include "base/functional/callback_helpers.h"
#include "base/task/sequenced_task_runner.h"
#include "base/files/file_util.h"
#include "components/prefs/pref_service.h"
#include "chrome/browser/browsing_data/chrome_browsing_data_remover_constants.h"
#include "chrome/browser/profiles/delete_profile_helper.h"
#include "chrome/browser/profiles/nuke_profile_directory_utils.h"
#include "chrome/browser/profiles/profile_attributes_storage.h"
#include "chrome/browser/profiles/profile_attributes_storage_observer.h"
#include "content/public/browser/browsing_data_remover.h"
#include "content/public/browser/browsing_data_filter_builder.h"
#include "net/base/registry_controlled_domains/registry_controlled_domain.h"
#include "components/sessions/content/content_serialized_navigation_builder.h"
#include "components/sessions/core/serialized_navigation_entry.h"
#include "content/public/browser/restore_type.h"
#include "chrome/browser/ui/crest/crest_permission_prompt.h"
#include "chrome/browser/ui/crest/crest_engine_extensions.h"
#include "chrome/browser/ui/crest/crest_engine_profiles.h"
#include "chrome/browser/ui/crest/crest_extension_prompt.h"
#include "extensions/browser/crx_installer.h"
#include "chrome/browser/extensions/extension_action_dispatcher.h"
#include "chrome/browser/ui/toolbar/toolbar_actions_model.h"
#include "extensions/browser/extension_registrar.h"
#include "extensions/browser/extension_registry_observer.h"
#include "extensions/browser/extension_icon_image.h"
#include "extensions/browser/extension_system.h"
#include "extensions/browser/management_policy.h"
#include "extensions/browser/disable_reason.h"
#include "extensions/browser/uninstall_reason.h"
#include "extensions/common/manifest_handlers/icons_handler.h"
#include "extensions/common/manifest_handlers/options_page_info.h"
#include "extensions/common/permissions/permissions_data.h"
#include "extensions/common/permissions/permission_message.h"

#include "extensions/browser/install/crx_install_error.h"
#include "components/version_info/version_info.h"
#include "chrome/browser/content_settings/host_content_settings_map_factory.h"
#include "components/content_settings/core/browser/host_content_settings_map.h"
#include "components/permissions/permission_request.h"
#include "components/permissions/permission_uma_util.h"
#include "chrome/browser/devtools/devtools_contents_resizing_strategy.h"
#include "chrome/browser/devtools/devtools_toggle_action.h"
#include "chrome/browser/devtools/devtools_window.h"
#include "chrome/browser/extensions/api/side_panel/side_panel_service.h"
#include "chrome/browser/extensions/commands/command_service.h"
#include "chrome/browser/extensions/extension_action_runner.h"
#include "chrome/browser/extensions/extension_tab_util.h"
#include "extensions/browser/event_router.h"
#include "extensions/browser/permissions/active_tab_permission_granter.h"
#include "extensions/common/command.h"
#include "extensions/common/api/extension_action/action_info.h"
#include "extensions/common/mojom/context_type.mojom.h"
#include "ui/base/accelerators/accelerator.h"
#include "ui/base/accelerators/command.h"
#include "ui/events/cocoa/cocoa_event_utils.h"
#include "ui/events/keycodes/keyboard_code_conversion_mac.h"
#include "chrome/browser/extensions/extension_view.h"
#include "chrome/browser/extensions/extension_view_host.h"
#include "chrome/browser/extensions/extension_view_host_factory.h"
#include "extensions/browser/extension_action.h"
#include "extensions/browser/extension_action_manager.h"
#include "extensions/browser/extension_host_observer.h"
#include "extensions/browser/extension_registry.h"
#include "extensions/browser/extension_util.h"
#include "extensions/common/extension.h"
#include "extensions/common/manifest.h"
#include "components/sessions/content/session_tab_helper.h"
#include "content/public/browser/render_frame_host.h"
#include "content/public/browser/navigation_throttle.h"
#include "content/public/browser/page_navigator.h"
#include "content/public/browser/render_widget_host_view.h"
#include "ui/gfx/image/image.h"
#include "extensions/browser/pref_names.h"
#include "components/prefs/pref_service.h"
#include "components/viz/common/frame_sinks/copy_output_result.h"
#include "base/time/time.h"
#include "components/find_in_page/find_tab_helper.h"
#include "components/find_in_page/find_result_observer.h"
#include "components/find_in_page/find_types.h"
#include "components/zoom/zoom_controller.h"
#include "third_party/blink/public/common/page/page_zoom.h"
#include "base/functional/bind.h"
#include "chrome/browser/browser_process.h"
#include "chrome/browser/download/download_item_model.h"
#include "chrome/browser/ui/crest/crest_download_hooks.h"
#include "chrome/browser/download/download_confirmation_result.h"
#include "components/download/public/common/download_item.h"
#include "content/public/browser/download_item_utils.h"
#include "content/public/browser/download_manager.h"
#include "ui/shell_dialogs/selected_file_info.h"
#include "chrome/browser/ui/browser_window/public/global_browser_collection.h"
#include "chrome/browser/profiles/profile_manager.h"
#include "chrome/browser/profiles/profile_destroyer.h"
#include "chrome/browser/profiles/keep_alive/scoped_profile_keep_alive.h"
#include "chrome/browser/profiles/keep_alive/profile_keep_alive_types.h"
#include "chrome/browser/ui/tabs/tab_enums.h"
#include "base/command_line.h"
#include "base/no_destructor.h"
#include "base/uuid.h"
#include "base/strings/string_number_conversions.h"
#include "base/strings/string_util.h"
#include "base/strings/sys_string_conversions.h"
#include "base/strings/utf_string_conversions.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/ui/browser.h"
#include "chrome/browser/ui/navigator/browser_navigator.h"
#include "chrome/browser/ui/navigator/browser_navigator_params.h"
#include "chrome/browser/ui/crest/crest_chrome_hooks.h"
#include "chrome/browser/ui/crest/crest_engine_binding.h"
#include "chrome/browser/ui/crest/crest_engine_page.h"
#include "chrome/browser/ui/crest/crest_engine_prompts.h"
#include "chrome/browser/ui/tabs/tab_strip_model.h"
#include "chrome/browser/ui/tabs/tab_strip_model_observer.h"
#include "components/tabs/public/tab_interface.h"
#include "content/public/browser/navigation_controller.h"
#include "content/public/browser/navigation_entry.h"
#include "content/public/browser/navigation_handle.h"
#include "content/public/browser/web_contents.h"
#include "content/public/browser/javascript_dialog_manager.h"
#include "net/base/auth.h"
#include "ui/views/widget/widget.h"
#include "content/public/browser/web_contents_observer.h"
#include "content/public/common/drop_data.h"
#include "net/base/apple/url_conversions.h"
#include "components/password_manager/core/common/password_manager_pref_names.h"
#include "components/security_state/content/security_state_tab_helper.h"
#include "mojo/public/cpp/bindings/receiver.h"
#include "components/security_state/core/security_state.h"
#include "content/public/browser/ssl_status.h"
#include "net/base/net_errors.h"
#include "net/cert/cert_status_flags.h"
#include "net/cert/x509_certificate.h"
#include "net/cert/x509_util.h"
#include "content/public/browser/global_routing_id.h"
#include "ui/base/page_transition_types.h"

// What an extension shortcut did, for the platform.
@interface CrestExtensionShortcutResult : NSObject <CrestExtensionShortcut>
@property(nonatomic, nullable) NSString* actionExtensionID;
@end
@implementation CrestExtensionShortcutResult
@end

// The window an extension action's popup is shown in.
//
// Crest does not use `NSPopover` for these. On macOS 27 the popover composites
// a translucent system material with whatever it hosts, so an extension
// painting an opaque `#181A1B` measured `#68555B` on screen — a white haze over
// the extension's own rendering. Neither an opaque page base nor an opaque
// browser surface changes that, and an opaque view behind the web contents
// occludes the renderer's remote layer and leaves the popup blank. This is a
// plain borderless window instead: nothing of Crest's is composited with the
// extension's document, so what the renderer paints is what reaches the screen.
//
// It becomes key so the popup's own fields can be typed into, and is added as a
// child of the Crest window it was anchored in, so it travels and orders with
// it. There is no arrow: the arrow of a system popover is filled with the
// popover's own background colour, and Crest does not know the colour an
// extension's document paints.
@interface CrestExtensionPopupWindow : NSWindow
@end
@implementation CrestExtensionPopupWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

namespace {
// AppKit hosting follows Mori's native ExtensionView bridge (MIT; see
// ThirdParty/Mori-LICENSE). Each instance belongs to one Crest page/profile.
class ExtensionPopup final : public extensions::ExtensionView,
                             public extensions::ExtensionHostObserver {
 public:
  ExtensionPopup(std::unique_ptr<extensions::ExtensionViewHost> host, NSView* anchor_view, NSRect anchor_rect)
      : host_(std::move(host)), anchor_view_(anchor_view), anchor_rect_(anchor_rect) {
    host_->set_view(this);
    host_->AddObserver(this);
    auto weak = weak_factory_.GetWeakPtr();
    host_->SetCloseHandler(base::BindOnce([](base::WeakPtr<ExtensionPopup> popup, extensions::ExtensionHost*) {
      dispatch_async(dispatch_get_main_queue(), ^{ if (popup) popup->Close(); });
    }, weak));
    window_ = [[CrestExtensionPopupWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, kDefaultWidth, kDefaultHeight)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    window_.releasedWhenClosed = NO;
    window_.opaque = NO;
    window_.backgroundColor = NSColor.clearColor;
    window_.hasShadow = YES;
    window_.movable = NO;
    window_.animationBehavior = NSWindowAnimationBehaviorNone;
    window_.collectionBehavior =
        NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorIgnoresCycle;
    // A plain layer-backed container, not a vibrancy view: it contributes only
    // the rounded corners Crest's own controls use. The renderer's view is its
    // one subview, with nothing opaque between them, so the remote layer the
    // renderer draws into is never occluded.
    NSView* container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kDefaultWidth, kDefaultHeight)];
    container.wantsLayer = YES;
    container.layer.backgroundColor = NSColor.clearColor.CGColor;
    container.layer.cornerRadius = kCornerRadius;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.masksToBounds = YES;
    container.autoresizesSubviews = YES;
    NSView* view = host_->host_contents()->GetNativeView().GetNativeNSView();
    view.frame = container.bounds;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [container addSubview:view];
    window_.contentView = container;
    host_->CreateRendererSoon();
  }
  ~ExtensionPopup() override { Close(); }
  void Close() {
    weak_factory_.InvalidateWeakPtrs();
    for (id monitor in monitors_) [NSEvent removeMonitor:monitor];
    monitors_ = nil;
    for (id observation in observations_) [[NSNotificationCenter defaultCenter] removeObserver:observation];
    observations_ = nil;
    if (window_) {
      if (NSWindow* parent = window_.parentWindow) [parent removeChildWindow:window_];
      [window_ orderOut:nil];
      window_.contentView = [[NSView alloc] initWithFrame:NSZeroRect];
      [window_ close];
      window_ = nil;
    }
    if (host_) { host_->RemoveObserver(this); host_.reset(); }
  }
  gfx::NativeView GetNativeView() override { return host_ ? host_->host_contents()->GetNativeView() : gfx::NativeView(); }
  void ResizeDueToAutoResize(content::WebContents*, const gfx::Size& size) override {
    if (!window_) return;
    content_size_ = NSMakeSize(std::clamp(size.width(), 25, 800), std::clamp(size.height(), 25, 600));
    Position();
  }
  void RenderFrameCreated(content::RenderFrameHost* frame) override {
    if (auto* view = frame->GetView()) view->EnableAutoResize(gfx::Size(25, 25), gfx::Size(800, 600));
  }
  bool HandleKeyboardEvent(content::WebContents*, const input::NativeWebKeyboardEvent&) override { return false; }
  void OnLoaded() override {
    NSWindow* parent = anchor_view_.window;
    if (!parent || !window_ || presented_) { if (!parent) Close(); return; }
    presented_ = true;
    Position();
    [parent addChildWindow:window_ ordered:NSWindowAbove];
    [window_ makeKeyAndOrderFront:nil];
    Observe(parent);
    if (host_) host_->host_contents()->Focus();
  }
  void OnExtensionHostDestroyed(extensions::ExtensionHost* host) override {
    if (host_.get() == host) host_.release();
    Close();
  }
 private:
  static constexpr CGFloat kDefaultWidth = 360;
  static constexpr CGFloat kDefaultHeight = 320;
  // The radius Crest's own controls use.
  static constexpr CGFloat kCornerRadius = 12;
  static constexpr CGFloat kAnchorGap = 6;
  static constexpr CGFloat kScreenMargin = 8;
  static constexpr unsigned short kEscapeKeyCode = 53;

  // Places the popup under the control it was opened from, flipping above it
  // and sliding along the screen when there is not room below or beside it.
  void Position() {
    NSWindow* parent = anchor_view_.window;
    if (!window_ || !parent) return;
    const NSRect anchor = [parent convertRectToScreen:[anchor_view_ convertRect:anchor_rect_ toView:nil]];
    NSRect visible = (parent.screen ?: NSScreen.mainScreen).visibleFrame;
    NSRect frame = NSMakeRect(NSMidX(anchor) - content_size_.width / 2,
                              NSMinY(anchor) - kAnchorGap - content_size_.height,
                              content_size_.width, content_size_.height);
    if (NSMinY(frame) < NSMinY(visible) + kScreenMargin) {
      const CGFloat above = NSMaxY(anchor) + kAnchorGap;
      if (above + content_size_.height <= NSMaxY(visible) - kScreenMargin) frame.origin.y = above;
      else frame.origin.y = NSMinY(visible) + kScreenMargin;
    }
    frame.origin.x = std::clamp(frame.origin.x, NSMinX(visible) + kScreenMargin,
                                std::max(NSMinX(visible) + kScreenMargin,
                                         NSMaxX(visible) - kScreenMargin - content_size_.width));
    [window_ setFrame:frame display:YES];
  }

  // Transient like the popover it replaces: a click outside it, Escape, the
  // window it belongs to moving, resizing or minimising, and Crest going to the
  // background all dismiss it. The extension closing its own popup, the host
  // being destroyed and the extension unloading come through the host.
  void Observe(NSWindow* parent) {
    auto weak = weak_factory_.GetWeakPtr();
    NSWindow* popup = window_;
    const NSEventMask clicks = NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown;
    monitors_ = @[
      [NSEvent addLocalMonitorForEventsMatchingMask:clicks | NSEventMaskKeyDown
                                            handler:^NSEvent*(NSEvent* event) {
        if (!weak) return event;
        if (event.type == NSEventTypeKeyDown) {
          if (event.keyCode != kEscapeKeyCode) return event;
          weak->Close();
          return nil;
        }
        if (event.window != popup) weak->Close();
        return event;
      }],
      [NSEvent addGlobalMonitorForEventsMatchingMask:clicks handler:^(NSEvent*) {
        if (weak) weak->Close();
      }],
    ];
    NSMutableArray* observations = [NSMutableArray array];
    auto dismiss = ^(NSNotification*) {
      dispatch_async(dispatch_get_main_queue(), ^{ if (weak) weak->Close(); });
    };
    for (NSNotificationName name in @[NSWindowDidResizeNotification, NSWindowDidMoveNotification,
                                      NSWindowDidMiniaturizeNotification, NSWindowWillCloseNotification])
      [observations addObject:[[NSNotificationCenter defaultCenter] addObserverForName:name object:parent
          queue:NSOperationQueue.mainQueue usingBlock:dismiss]];
    [observations addObject:[[NSNotificationCenter defaultCenter]
        addObserverForName:NSApplicationDidResignActiveNotification object:NSApp
                     queue:NSOperationQueue.mainQueue usingBlock:dismiss]];
    observations_ = observations;
  }

  std::unique_ptr<extensions::ExtensionViewHost> host_;
  NSView* __weak anchor_view_;
  NSRect anchor_rect_;
  CrestExtensionPopupWindow* __strong window_ = nil;
  NSArray* __strong monitors_ = nil;
  NSArray* __strong observations_ = nil;
  NSSize content_size_ = NSMakeSize(kDefaultWidth, kDefaultHeight);
  bool presented_ = false;
  base::WeakPtrFactory<ExtensionPopup> weak_factory_{this};
};

// An extension side panel is a Crest split-row card, not a Views
// SidePanelEntry: Crest never instantiates Chrome's SidePanelCoordinator. Only
// the extension host and its view belong to Chromium; placement, sizing and
// dismissal are the core's, and the card owns this object's lifetime.
class ExtensionSidePanel final : public extensions::ExtensionView,
                                 public extensions::ExtensionHostObserver {
 public:
  ExtensionSidePanel(std::unique_ptr<extensions::ExtensionViewHost> host,
                     std::string extension_id, void (^closed)(void))
      : host_(std::move(host)), extension_id_(std::move(extension_id)), closed_([closed copy]) {
    container_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 360, 600)];
    container_.autoresizesSubviews = YES;
    host_->set_view(this);
    host_->AddObserver(this);
    auto weak = weak_factory_.GetWeakPtr();
    // The panel's own document called window.close(), or the extension
    // retracted its entry. Either way the card goes away with it.
    host_->SetCloseHandler(base::BindOnce([](base::WeakPtr<ExtensionSidePanel> panel, extensions::ExtensionHost*) {
      dispatch_async(dispatch_get_main_queue(), ^{ if (panel) panel->Dismiss(); });
    }, weak));
    NSView* view = host_->host_contents()->GetNativeView().GetNativeNSView();
    view.frame = container_.bounds;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [container_ addSubview:view];
    host_->CreateRendererSoon();
  }
  ~ExtensionSidePanel() override { Close(); }
  NSView* container() { return container_; }
  const std::string& extension_id() const { return extension_id_; }
  // The extension retracted its entry or unloaded. Tell the core to drop the
  // card; the panel document goes away with this object.
  void Retract() { Dismiss(); }
  void Close() {
    weak_factory_.InvalidateWeakPtrs();
    closed_ = nil;
    if (host_) { host_->RemoveObserver(this); host_.reset(); }
  }
  gfx::NativeView GetNativeView() override {
    return host_ ? host_->host_contents()->GetNativeView() : gfx::NativeView();
  }
  // The card is laid out by the row, so the panel document never resizes it.
  void ResizeDueToAutoResize(content::WebContents*, const gfx::Size&) override {}
  void RenderFrameCreated(content::RenderFrameHost*) override {}
  bool HandleKeyboardEvent(content::WebContents*, const input::NativeWebKeyboardEvent&) override { return false; }
  void OnLoaded() override {}
  void OnExtensionHostDestroyed(extensions::ExtensionHost* host) override {
    if (host_.get() == host) host_.release();
    Dismiss();
  }
 private:
  // Hands the dismissal to the core, which removes the card and then releases
  // this object. Nothing may touch `this` afterwards.
  void Dismiss() {
    void (^closed)(void) = closed_;
    Close();
    if (closed) closed();
  }
  std::unique_ptr<extensions::ExtensionViewHost> host_;
  std::string extension_id_;
  void (^__strong closed_)(void);
  NSView* __strong container_ = nil;
  base::WeakPtrFactory<ExtensionSidePanel> weak_factory_{this};
};
// The docked DevTools frontend inside a Crest page card.
//
// Chromium owns the frontend WebContents and everything in it, including the
// undock and close buttons. This owns only the container the core mounts, so a
// dock-side or size change is a relayout of a card that is already on screen
// rather than a new one, and the resizing strategy the frontend publishes is
// kept here beside it.
class DevToolsPanel {
 public:
  explicit DevToolsPanel(content::WebContents* frontend)
      : frontend_(frontend->GetWeakPtr()) {
    container_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
    container_.autoresizesSubviews = YES;
    NSView* view = frontend->GetNativeView().GetNativeNSView();
    view.frame = container_.bounds;
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [container_ addSubview:view];
  }
  NSView* container() { return container_; }
  bool hosts(content::WebContents* frontend) const {
    return frontend_ && frontend_.get() == frontend;
  }

 private:
  base::WeakPtr<content::WebContents> frontend_;
  NSView* __strong container_ = nil;
};
class NativePermissionPrompt final : public permissions::PermissionPrompt {
 public:
  NativePermissionPrompt(NSWindow* window, Delegate* delegate)
      : delegate_(delegate->GetWeakPtr()), window_(window) {
    alert_ = [[NSAlert alloc] init];
    alert_.messageText = base::SysUTF8ToNSString(delegate->GetRequestingOrigin().spec());
    NSMutableArray* requests = [NSMutableArray array];
    for (const auto& request : delegate->Requests())
      [requests addObject:base::SysUTF16ToNSString(request->GetMessageTextFragment())];
    alert_.informativeText = [requests componentsJoinedByString:@"\n"];
    [alert_ addButtonWithTitle:@"Allow"];
    [alert_ addButtonWithTitle:@"Block"];
    [alert_ addButtonWithTitle:@"Not Now"];
    auto weak = weak_factory_.GetWeakPtr();
    [alert_ beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
      if (!weak || !weak->delegate_) return;
      weak->responded_ = true;
      auto current_delegate = weak->delegate_;
      if (response == NSAlertFirstButtonReturn) current_delegate->Accept(std::monostate());
      else if (response == NSAlertSecondButtonReturn) current_delegate->Deny(std::monostate());
      else current_delegate->Dismiss(std::monostate());
    }];
  }
  ~NativePermissionPrompt() override {
    weak_factory_.InvalidateWeakPtrs();
    if (!responded_ && alert_.window.sheetParent) [window_ endSheet:alert_.window returnCode:NSModalResponseCancel];
  }
  bool UpdateAnchor() override { return true; }
  TabSwitchingBehavior GetTabSwitchingBehavior() override { return kDestroyPromptButKeepRequestPending; }
  permissions::PermissionPromptDisposition GetPromptDisposition() const override { return permissions::PermissionPromptDisposition::ANCHORED_BUBBLE; }
  bool IsAskPrompt() const override { return true; }
  std::optional<gfx::Rect> GetViewBoundsInScreen() const override { return std::nullopt; }
  bool ShouldFinalizeRequestAfterDecided() const override { return true; }
  std::vector<permissions::ElementAnchoredBubbleVariant> GetPromptVariants() const override { return {}; }
  std::optional<permissions::feature_params::PermissionElementPromptPosition> GetPromptPosition() const override { return std::nullopt; }
 private:
  base::WeakPtr<Delegate> delegate_;
  NSWindow* __weak window_;
  NSAlert* __strong alert_;
  bool responded_ = false;
  base::WeakPtrFactory<NativePermissionPrompt> weak_factory_{this};
};
struct Page;
struct BrowserOwner;
struct HostState {
  const base::Time started_at = base::Time::Now();
  // Crest's own UI, which the framework attaches when it starts.
  id<CrestMacUI> ui = nil;
  Browser* bootstrap = nullptr;
  bool started = false;
  bool disposing = false;
  bool quitting = false;
  std::string creating_window;
  // The profile `chrome.windows.create` is about to create a Browser in, for
  // the one turn between asking and creating: that Browser gets a Crest window
  // of its own. Every other Browser the engine creates joins an open window.
  Profile* own_window_profile = nullptr;
  std::map<std::string, std::unique_ptr<BrowserOwner>> browsers;
  std::map<std::string, std::unique_ptr<Page>> pages;
  // The action popup opened from a Space that has no page. A page's own popup
  // lives on the page; this one has no page to live on and only one can be
  // open at a time, because an action popup is transient.
  std::unique_ptr<ExtensionPopup> space_extension_popup;
  // System sign-in requests from other apps, by the Quick Window running each.
  // Requests that arrive before the native root starts wait in `pending_*`.
  std::map<std::string, ASWebAuthenticationSessionRequest*> authentication_sessions;
  std::vector<ASWebAuthenticationSessionRequest*> pending_authentication_sessions;
};
HostState& State() { static base::NoDestructor<HostState> state; return *state; }

// Crest's own UI, or nil before the framework starts.
id<CrestMacUI> UI() { return State().ui; }

// The text the shell keeps a Crest identifier as.
std::string KeyFor(NSUUID* identifier) {
  return identifier ? base::SysNSStringToUTF8(identifier.UUIDString) : std::string();
}

// A Crest identifier the shell keeps as text, or nil for none.
NSUUID* UUIDFor(const std::string& identifier) {
  return identifier.empty() ? nil : [[NSUUID alloc] initWithUUIDString:base::SysUTF8ToNSString(identifier)];
}

// System sign-in (`ASWebAuthenticationSession`). Chromium's own handler opens a
// Views popup Browser in the last-used engine profile; that profile belongs to
// no Space and the popup never appears, so the sign-in page loads where nobody
// can see it. Crest runs the session in a Quick Window of the Space an external
// link from the requesting app routes to, and completes it when that page
// reaches the requester's callback. The window shows the page's address and
// has no editable location, which is what the system API requires.
//
// An ephemeral-session request still uses the Space's profile: the API leaves
// honoring it to the browser, and a Space is Crest's unit of identity.
void EndAuthenticationSession(const std::string& window, NSURL* callback, bool close_window) {
  auto& sessions = State().authentication_sessions;
  auto found = sessions.find(window);
  if (found == sessions.end()) return;
  ASWebAuthenticationSessionRequest* request = found->second;
  sessions.erase(found);
  if (callback) {
    [request completeWithCallbackURL:callback];
  } else {
    [request cancelWithError:[NSError errorWithDomain:ASWebAuthenticationSessionErrorDomain
                                                 code:ASWebAuthenticationSessionErrorCodeCanceledLogin
                                             userInfo:nil]];
  }
  if (NSUUID* identifier = close_window ? UUIDFor(window) : nil) [UI() closeAuthenticationSession:identifier];
}

// The system's sign-in broker hands out one request at a time and waits for
// the browser to finish it; a request left open when Crest quits would hold
// every later sign-in until the broker restarts.
void CancelAllAuthenticationSessions() {
  auto& state = State();
  std::vector<ASWebAuthenticationSessionRequest*> requests =
      std::move(state.pending_authentication_sessions);
  state.pending_authentication_sessions.clear();
  for (const auto& [window, request] : state.authentication_sessions) requests.push_back(request);
  state.authentication_sessions.clear();
  for (ASWebAuthenticationSessionRequest* request : requests) {
    [request cancelWithError:[NSError errorWithDomain:ASWebAuthenticationSessionErrorDomain
                                                 code:ASWebAuthenticationSessionErrorCodeCanceledLogin
                                             userInfo:nil]];
  }
}

void StartAuthenticationSession(ASWebAuthenticationSessionRequest* request) {
  if (State().disposing || State().quitting) {
    [request cancelWithError:[NSError errorWithDomain:ASWebAuthenticationSessionErrorDomain
                                                 code:ASWebAuthenticationSessionErrorCodePresentationContextInvalid
                                             userInfo:nil]];
    return;
  }
  NSUUID* window = NSUUID.UUID;
  const std::string key = base::SysNSStringToUTF8(window.UUIDString);
  State().authentication_sessions[key] = request;
  if (![UI() openAuthenticationSession:request.URL window:window]) EndAuthenticationSession(key, nil, false);
}

// Crest's vault owns credentials in every window, so the engine's own password
// manager never saves, offers fills or shows its bubbles — in a private window
// as much as in a Space, whether or not a credential bridge is installed. A
// private profile keeps its preferences in memory and a private password
// store reads its original profile's settings, so both are turned off.
void DisableEnginePasswordManager(content::WebContents* contents) {
  auto* profile = contents ? Profile::FromBrowserContext(contents->GetBrowserContext()) : nullptr;
  if (!profile) return;
  for (Profile* target : {profile, profile->GetOriginalProfile()}) {
    auto* prefs = target ? target->GetPrefs() : nullptr;
    if (prefs && prefs->GetBoolean(password_manager::prefs::kCredentialsEnableService))
      prefs->SetBoolean(password_manager::prefs::kCredentialsEnableService, false);
  }
}

// The shell's side of a page: the Browser that holds its WebContents and the
// views it hosts over it.
struct Page final : content::WebContentsObserver {
  Page(content::WebContents* contents, Browser* owner, std::string profile_id)
      : content::WebContentsObserver(contents), browser(owner), profile(std::move(profile_id)) {
    DisableEnginePasswordManager(contents);
  }
  // The page's identity, as the platform spells it.
  std::string Key() const {
    for (const auto& [id, page] : State().pages)
      if (page.get() == this) return id;
    return std::string();
  }
  Browser* browser;
  std::string profile;
  bool closing = false;
  std::unique_ptr<ExtensionPopup> extension_popup;
  std::unique_ptr<ExtensionSidePanel> side_panel;
  std::unique_ptr<DevToolsPanel> devtools;
  void BeforeUnloadDialogCancelled() override { closing = false; }
  void BeforeUnloadFired(bool proceed) override {
    if (!proceed) closing = false;
  }
  void WebContentsDestroyed() override {
    extension_popup.reset();
    side_panel.reset();
    devtools.reset();
    Observe(nullptr);
  }
};


void OfferNativePage(base::WeakPtr<content::WebContents> contents, bool foreground);



struct BrowserOwner final : TabStripModelObserver {
  BrowserOwner(Browser* value, std::string native_window)
      : browser(value), window(std::move(native_window)), strip(value->tab_strip_model()) {
    strip->AddObserver(this);
  }
  ~BrowserOwner() override { if (strip) strip->RemoveObserver(this); }
  Browser* browser;
  std::string window;
  TabStripModel* strip;
  // Set only for a Browser the engine created for itself. `space` names the
  // Crest Space that reserved `window`; the window itself is opened lazily,
  // when the first tab that cannot join an opener is offered.
  std::string space;
  bool engine_window = false;
  bool presented = false;
  bool focused = true;
  void OnTabStripModelChanged(TabStripModel*, const TabStripModelChange& change,
                             const TabStripSelectionChange& selection) override {
    if (change.type() != TabStripModelChange::kInserted || State().disposing) return;
    for (const auto& inserted : change.GetInsert()->contents) {
      auto weak = inserted.contents->GetWeakPtr();
      const bool foreground = selection.new_contents == inserted.contents;
      // Core-created pages are registered before this next UI-thread turn.
      dispatch_async(dispatch_get_main_queue(), ^{ OfferNativePage(weak, foreground); });
    }
  }
  void OnTabCloseCancelled(const tabs::TabInterface* tab) override {
    for (auto& [id, page] : State().pages) {
      if (page->web_contents() == tab->GetContents() && page->closing) {
        page->closing = false;
        return;
      }
    }
  }
  void OnTabStripModelDestroyed(TabStripModel*) override { strip = nullptr; }
};

// Offers the core a tab the engine opened by itself, in the Crest window its
// Browser belongs to. The binding reports the offer; the core adopts it for a
// tab of its own or refuses it.
void OfferNativePage(base::WeakPtr<content::WebContents> contents, bool foreground) {
  auto& state = State();
  auto& binding = crest::EngineBinding::Get();
  if (!contents || state.disposing || binding.disposing()) return;
  for (const auto& [id, page] : state.pages) if (page->web_contents() == contents.get()) return;
  BrowserOwner* host = nullptr;
  for (const auto& [id, owner] : state.browsers)
    if (owner->strip && owner->strip->GetIndexOfWebContents(contents.get()) >= 0) { host = owner.get(); break; }
  // A window the engine created for itself (chrome.windows.create, an
  // extension app window) has no Crest window until one of its tabs needs it.
  // A renderer popup keeps its opener's window instead: the core opens its
  // tab beside the page that opened it.
  content::RenderFrameHost* opener = contents->GetOpener();
  const bool opened_by_page = opener && binding.PageFor(content::WebContents::FromRenderFrameHost(opener));
  if (host && host->engine_window && !host->presented && !opened_by_page) {
    host->presented = true;
    NSUUID* window = UUIDFor(host->window);
    NSUUID* space = UUIDFor(host->space);
    if (window && space) [UI() presentEngineWindow:window space:space focused:host->focused ? YES : NO];
  }
  binding.Offer(contents.get(), host ? host->window : std::string(), host ? host->space : std::string(), foreground);
}

Browser* BrowserFor(const std::string& profile_id, const std::string& window_id) {
  auto& state = State();
  const std::string key = profile_id + "/" + window_id;
  if (auto found = state.browsers.find(key); found != state.browsers.end())
    return found->second->browser;
  Profile* profile = crest::EngineBinding::Get().Profiles().Find(profile_id);
  if (!profile) return nullptr;
  // Named before the status check as well as the creation: a window the core is
  // opening for itself is never subject to `CanCreateEngineBrowser`.
  state.creating_window = window_id;
  if (Browser::GetCreationStatusForProfile(profile) != BrowserWindowInterface::CreationStatus::kOk) {
    state.creating_window.clear();
    return nullptr;
  }
  Browser* browser = Browser::Create(Browser::CreateParams(profile, false));
  state.creating_window.clear();
  state.browsers.emplace(key, std::make_unique<BrowserOwner>(browser, window_id));
  return browser;
}

// Reserves the Crest window that will host a Browser the engine created for
// itself, so `WindowForBrowser` resolves and its tabs can be offered with a
// window the core recognizes. The window is opened only once a tab needs it.
// A profile with no Space to host it is declined rather than routed into an
// unrelated Space; an off-the-record profile belongs to the private window
// composition and is declined when that window is closed.
bool RegisterEngineBrowser(Browser* browser) {
  auto& state = State();
  const bool own_window = state.own_window_profile == browser->GetProfile();
  state.own_window_profile = nullptr;
  const auto& profiles = crest::EngineBinding::Get().Profiles();
  const std::string profile_id = profiles.IdFor(browser->GetProfile());
  if (profile_id.empty() || profiles.IsDeleting(profile_id)) return false;
  NSUUID* profile = UUIDFor(profile_id);
  id<CrestEngineWindowPlacement> placement =
      profile ? [UI() reserveEngineWindowForProfile:profile ownWindow:own_window ? YES : NO] : nil;
  if (!placement) return false;
  const std::string window = base::SysNSStringToUTF8(placement.window.UUIDString);
  // A window that already has a Browser keeps it for its own pages. This one
  // is keyed apart, and each tab it offers moves into that Browser once the
  // window adopts it.
  std::string key = profile_id + "/" + window;
  if (state.browsers.contains(key)) key = "engine/" + base::Uuid::GenerateRandomV4().AsLowercaseString();
  auto owner = std::make_unique<BrowserOwner>(browser, window);
  owner->space = base::SysNSStringToUTF8(placement.space.UUIDString);
  owner->engine_window = true;
  state.browsers.emplace(key, std::move(owner));
  return true;
}

Page* FindPage(NSString* identifier) {
  auto found = State().pages.find(base::SysNSStringToUTF8(identifier));
  return found == State().pages.end() ? nullptr : found->second.get();
}

// Lets a page go: the shell forgets it, then its WebContents is destroyed.
void DisposePage(const std::string& id) {
  auto& state = State();
  auto found = state.pages.find(id);
  if (found == state.pages.end()) return;
  auto* contents = found->second->web_contents();
  Browser* browser = found->second->browser;
  state.pages.erase(found);  // Remove callbacks before destroying WebContents.
  if (!contents) return;
  TabStripModel* strip = browser->tab_strip_model();
  const int index = strip->GetIndexOfWebContents(contents);
  if (index >= 0) strip->DetachAndDeleteWebContentsAt(index);
}

// Closes every Browser of `profile`: an empty one at once, and one with tabs
// by closing its tabs, which closes the Browser.
void CloseBrowsers(Profile* profile) {
  auto& state = State();
  for (;;) {
    auto owner = std::find_if(state.browsers.begin(), state.browsers.end(),
        [&](const auto& entry) { return entry.second->browser->GetProfile() == profile; });
    if (owner == state.browsers.end()) break;
    Browser* browser = owner->second->browser;
    TabStripModel* strip = browser->tab_strip_model();
    if (strip->empty()) browser->SynchronouslyDestroyBrowser();
    else for (int index = strip->count() - 1; index >= 0; --index) strip->DetachAndDeleteWebContentsAt(index);
  }
}

// What the Mac shell does for the portable binding. TRANSITIONAL: each part
// moves into the binding with its area.
class MacShell final : public crest::EngineBinding::Shell {
 public:
  // The WebContents goes in its window's Browser. The controller keeps its
  // initial entry until the binding supplies the first address or restored
  // history: navigating to about:blank here would race restoration and can
  // leave a spurious Back entry.
  content::WebContents* CreateContents(const std::string& page, Profile* profile, const std::string& profile_id,
                                       const std::string& window) override {
    auto& state = State();
    if (state.disposing || state.pages.contains(page)) return nullptr;
    // Reclaim observers only after their WebContents destruction callback returned.
    std::erase_if(state.pages, [](const auto& pair) { return !pair.second->web_contents(); });
    Browser* browser = BrowserFor(profile_id, window);
    if (!browser) return nullptr;
    content::WebContents::CreateParams params(profile);
    params.initially_hidden = true;
    params.desired_renderer_state = content::WebContents::CreateParams::kNoRendererProcess;
    auto owned_contents = content::WebContents::Create(params);
    auto* contents = owned_contents.get();
    browser->tab_strip_model()->AddWebContents(std::move(owned_contents), -1, ui::PAGE_TRANSITION_AUTO_TOPLEVEL,
                                               AddTabTypes::ADD_NONE);
    state.pages.emplace(page, std::make_unique<Page>(contents, browser, profile_id));
    return contents;
  }

  // The page stays in the Browser the engine opened it in until its view
  // attaches, which moves it into its window's Browser.
  bool AdoptContents(const std::string& page, content::WebContents* contents, const std::string& profile) override {
    auto& state = State();
    if (state.disposing || state.pages.contains(page)) return false;
    Browser* browser = nullptr;
    for (const auto& [id, owner] : state.browsers)
      if (owner->strip && owner->strip->GetIndexOfWebContents(contents) >= 0) { browser = owner->browser; break; }
    if (!browser) return false;
    state.pages.emplace(page, std::make_unique<Page>(contents, browser, profile));
    return true;
  }

  void CloseOffered(content::WebContents* contents) override {
    for (const auto& [id, owner] : State().browsers) {
      const int index = owner->strip ? owner->strip->GetIndexOfWebContents(contents) : -1;
      if (index >= 0) {
        owner->strip->DetachAndDeleteWebContentsAt(index);
        return;
      }
    }
  }

  void DestroyContents(const std::string& page) override { DisposePage(page); }

  bool MoveToWindow(const std::string& page_id, const std::string& window_id) override {
    Page* page = FindPage(base::SysUTF8ToNSString(page_id));
    if (!page || !page->web_contents() || page->closing) return false;
    Browser* target = BrowserFor(page->profile, window_id);
    if (!target) return false;
    if (page->browser != target) {
      TabStripModel* source = page->browser->tab_strip_model();
      const int index = source->GetIndexOfWebContents(page->web_contents());
      if (index < 0) return false;
      // Preserve TabModel, navigation history, renderer and extension identity.
      auto tab = source->DetachTabAtForInsertion(index);
      page->browser = target;
      target->tab_strip_model()->InsertDetachedTabAt(
          target->tab_strip_model()->count(), std::move(tab), AddTabTypes::ADD_ACTIVE);
    }
    const int index = target->tab_strip_model()->GetIndexOfWebContents(page->web_contents());
    if (index < 0) return false;
    target->tab_strip_model()->ActivateTabAt(index);
    return true;
  }

  // The profiles' pages and Browsers close; the binding lets the profiles go.
  void ReleaseProfiles(const std::set<std::string>& profiles) override {
    auto& state = State();
    state.space_extension_popup.reset();
    std::vector<std::string> pages;
    for (const auto& [key, page] : state.pages)
      if (profiles.contains(page->profile)) pages.push_back(key);
    for (const auto& key : pages) DisposePage(key);
    for (const auto& id : profiles) {
      Profile* profile = crest::EngineBinding::Get().Profiles().Find(id);
      if (profile) CloseBrowsers(profile);
    }
  }

  // Drops any open panel card for `extension_id` in `profile`, for one tab or
  // for all of them. An extension that unloads or turns its entry off has no
  // panel left to show.
  void RetractSidePanels(Profile* profile, const std::string& extension_id, std::optional<int> tab_id) override {
    if (!profile) return;
    for (const auto& [id, page] : State().pages) {
      if (!page->side_panel || page->side_panel->extension_id() != extension_id) continue;
      auto* contents = page->web_contents();
      if (!contents || !page->browser) continue;
      // A private window's pages run in the off-the-record profile, while the
      // registry and panel options belong to the profile it was derived from.
      if (page->browser->GetProfile()->GetOriginalProfile() != profile->GetOriginalProfile()) continue;
      if (tab_id && sessions::SessionTabHelper::IdForTab(contents).id() != *tab_id) continue;
      page->side_panel->Retract();
      page->side_panel.reset();
    }
  }

  void DockInspector(const std::string& page_id, content::WebContents* frontend) override {
    Page* page = FindPage(base::SysUTF8ToNSString(page_id));
    if (!page) return;
    if (!frontend) {
      page->devtools.reset();
    } else if (!page->devtools || !page->devtools->hosts(frontend)) {
      page->devtools = std::make_unique<DevToolsPanel>(frontend);
    }
  }
};
// chrome.commands. Crest owns the key-equivalent path, so an event the core
// did not claim is matched against the extension keybindings itself rather
// than through Chrome's Views keybinding registry, which this build never
// creates. Modelled on `ExtensionKeybindingRegistry`: the same command
// service, the same active-tab grant, and the same `commands.onCommand`
// payload, without the accelerator table a Views window would maintain.
ui::Accelerator ShortcutAccelerator(NSEvent* event) {
  const ui::KeyboardCode key = ui::KeyboardCodeFromNSEvent(event);
  if (key == ui::VKEY_UNKNOWN) return ui::Accelerator();
  return ui::Accelerator(key, ui::EventFlagsFromModifiers(event.modifierFlags));
}
// Delivers a named command to its extension, granting the active-tab
// permission first so the extension can act on the page it was invoked over.
void DeliverExtensionCommand(Profile* profile, const extensions::Extension& extension,
                             const std::string& command, content::WebContents* contents) {
  base::ListValue args;
  args.Append(command);
  base::Value tab;
  if (contents) {
    if (auto* granter = extensions::ActiveTabPermissionGranter::FromWebContents(contents))
      granter->GrantIfRequested(&extension);
    // The action APIs are privileged extension contexts by construction.
    const auto scrub = extensions::ExtensionTabUtil::GetScrubTabBehavior(
        &extension, extensions::mojom::ContextType::kPrivilegedExtension, contents);
    tab = base::Value(extensions::ExtensionTabUtil::CreateTabObject(contents, scrub, &extension).ToValue());
  }
  args.Append(std::move(tab));
  auto event = std::make_unique<extensions::Event>(
      extensions::events::COMMANDS_ON_COMMAND, "commands.onCommand", std::move(args), profile);
  event->user_gesture = extensions::EventRouter::UserGestureState::kEnabled;
  extensions::EventRouter::Get(profile)->DispatchEventToExtension(extension.id(), std::move(event));
}
}  // namespace

@interface CrestChromiumMacShell : NSObject <CrestMacShell>
@end

// The UI framework's entry point: the shell's host, and the engine binding
// the framework registers with its core.
using CrestChromiumUIStart = void (*)(id<CrestMacShell> shell, const crest_engine_binding_t* binding,
                                      const uint8_t* fingerprint, size_t fingerprint_length,
                                      const crest_engine_pages_t* pages);

@implementation CrestChromiumMacShell
- (void)setPrivateSourceProfile:(NSUUID*)profileID {
  CHECK(NSThread.isMainThread);
  crest::EngineBinding::Get().SetPrivateSourceProfile(KeyFor(profileID));
}
- (NSView*)viewForPage:(NSUUID*)pageID {
  CHECK(NSThread.isMainThread);
  Page* page = FindPage(pageID.UUIDString);
  return page && page->web_contents() ? page->web_contents()->GetNativeView().GetNativeNSView() : nil;
}
- (BOOL)runExtension:(NSString*)extensionID page:(NSUUID*)pageID
         anchorView:(NSView*)anchorView anchorRect:(NSRect)anchorRect {
  CHECK(NSThread.isMainThread);
  Page* page = FindPage(pageID.UUIDString);
  if (!page || !page->web_contents() || !anchorView.window ||
      anchorView.window != crest::WindowForBrowser(page->browser)) return NO;
  Profile* profile = page->browser->GetProfile();
  const auto id = base::SysNSStringToUTF8(extensionID);
  const auto* extension = extensions::ExtensionRegistry::Get(profile)->enabled_extensions().GetByID(id);
  if (!extension || (profile->IsOffTheRecord() && !extensions::util::IsIncognitoEnabled(id, profile))) return NO;
  // Declined rather than navigated: an extension whose files are gone would
  // otherwise show Chromium's own ERR_FILE_NOT_FOUND page inside Crest's
  // popup window. The core states this as an unavailable action instead.
  if (!crest::EngineBinding::Get().Extensions().For(profile, page->profile).IsAvailable(*extension,
          extensions::ExtensionActionManager::Get(profile)->GetExtensionAction(*extension))) return NO;
  auto* contents = page->web_contents();
  const int index = page->browser->tab_strip_model()->GetIndexOfWebContents(contents);
  if (index < 0) return NO;
  page->browser->tab_strip_model()->ActivateTabAt(index);
  auto* runner = extensions::ExtensionActionRunner::GetForWebContents(contents);
  if (!runner) return NO;
  // This path is invoked only by the user's native extension action button.
  const auto result = runner->RunAction(extension, true);
  if (result == extensions::ExtensionAction::ShowAction::kNone) return YES;
  if (result == extensions::ExtensionAction::ShowAction::kToggleSidePanel) {
    // The action opens a panel instead of a popup. The card belongs to the
    // platform, so the click toggles the one this page is already showing.
    crest::EngineBinding::Get().RequestSidePanel(KeyFor(pageID), id,
                                                crest::engine::SidePanelRequest::kToggle);
    return YES;
  }
  if (result != extensions::ExtensionAction::ShowAction::kShowPopup) return NO;
  auto* action = extensions::ExtensionActionManager::Get(profile)->GetExtensionAction(*extension);
  if (!action) return NO;
  auto popup = extensions::ExtensionViewHostFactory::CreatePopupHost(*extension,
      action->GetPopupUrl(sessions::SessionTabHelper::IdForTab(contents).id()), page->browser);
  if (!popup) return NO;
  page->extension_popup = std::make_unique<ExtensionPopup>(std::move(popup), anchorView, anchorRect);
  return YES;
}
- (BOOL)runExtension:(NSString*)extensionID profile:(NSUUID*)profileID window:(NSUUID*)windowID
          anchorView:(NSView*)anchorView anchorRect:(NSRect)anchorRect {
  CHECK(NSThread.isMainThread);
  // The page-less click. There is no tab to activate, no host permission to
  // grant and nothing to inject, so only an action that carries its own popup
  // document can run: it is opened against the Space's Browser directly rather
  // than through the WebContents-scoped action runner.
  if (!anchorView.window) return NO;
  const auto profile_id = KeyFor(profileID);
  Profile* profile = crest::EngineBinding::Get().Profiles().Find(profile_id);
  if (!profile) return NO;
  Profile* owner = profile->GetOriginalProfile();
  const auto id = base::SysNSStringToUTF8(extensionID);
  const auto* extension = extensions::ExtensionRegistry::Get(owner)->enabled_extensions().GetByID(id);
  if (!extension) return NO;
  if (profile->IsOffTheRecord() && !extensions::util::IsIncognitoEnabled(id, owner)) return NO;
  auto* action = extensions::ExtensionActionManager::Get(owner)->GetExtensionAction(*extension);
  if (!action || !crest::EngineBinding::Get().Extensions().For(profile, profile_id).IsAvailable(*extension, action))
    return NO;
  if (action->action_type() == extensions::ActionInfo::Type::kPage) return NO;
  const GURL popup_url = action->GetPopupUrl(extensions::ExtensionAction::kDefaultTabId);
  if (!popup_url.is_valid()) return NO;
  Browser* browser = BrowserFor(profile_id, KeyFor(windowID));
  if (!browser || anchorView.window != crest::WindowForBrowser(browser)) return NO;
  auto popup = extensions::ExtensionViewHostFactory::CreatePopupHost(*extension, popup_url, browser);
  if (!popup) return NO;
  State().space_extension_popup = std::make_unique<ExtensionPopup>(std::move(popup), anchorView, anchorRect);
  return YES;
}
- (NSView*)openSidePanel:(NSString*)extensionID page:(NSUUID*)pageID closed:(void (^)(void))closed {
  CHECK(NSThread.isMainThread);
  Page* page = FindPage(pageID.UUIDString);
  const auto* extension = page ? crest::EngineExtensions::SidePanelExtension(
      page->web_contents(), base::SysNSStringToUTF8(extensionID)) : nullptr;
  if (!extension) return nil;
  auto* service = extensions::SidePanelService::Get(page->browser->GetProfile());
  auto* contents = page->web_contents();
  auto options = service->GetOptions(*extension, sessions::SessionTabHelper::IdForTab(contents).id());
  if (!options.path || options.path->empty() || options.enabled == false) return nil;
  const GURL url = extension->ResolveExtensionURL(*options.path);
  if (!url.is_valid()) return nil;
  auto panel = extensions::ExtensionViewHostFactory::CreateSidePanelHost(*extension, url,
      page->browser, page->browser->tab_strip_model()->GetTabForWebContents(contents));
  if (!panel) return nil;
  page->side_panel = std::make_unique<ExtensionSidePanel>(std::move(panel), extension->id(), closed);
  return page->side_panel->container();
}
- (void)closeSidePanelForPage:(NSUUID*)pageID {
  CHECK(NSThread.isMainThread);
  Page* page = FindPage(pageID.UUIDString);
  if (!page) return;
  page->side_panel.reset();
}
- (NSView*)devToolsViewForPage:(NSUUID*)pageID {
  CHECK(NSThread.isMainThread);
  Page* page = FindPage(pageID.UUIDString);
  return page && page->devtools ? page->devtools->container() : nil;
}
- (id<CrestExtensionShortcut>)dispatchExtensionShortcut:(NSEvent*)event page:(NSUUID*)pageID {
  CHECK(NSThread.isMainThread);
  Page* page = FindPage(pageID.UUIDString);
  if (!page || !page->web_contents() || State().disposing) return nil;
  const ui::Accelerator accelerator = ShortcutAccelerator(event);
  if (accelerator.key_code() == ui::VKEY_UNKNOWN) return nil;
  Profile* profile = page->browser->GetProfile();
  auto* commands = extensions::CommandService::Get(profile);
  if (!commands) return nil;
  for (const auto& extension : extensions::ExtensionRegistry::Get(profile)->enabled_extensions()) {
    const auto& id = extension->id();
    if (profile->IsOffTheRecord() && !extensions::util::IsIncognitoEnabled(id, profile)) continue;
    // `_execute_action` is the action itself, so the core runs it through the
    // same path as a click on the extension's own button.
    extensions::Command action;
    bool active = false;
    if (commands->GetExtensionActionCommand(id, extensions::ActionInfo::Type::kAction,
            extensions::CommandService::ACTIVE, &action, &active) &&
        active && action.accelerator() == accelerator) {
      CrestExtensionShortcutResult* result = [[CrestExtensionShortcutResult alloc] init];
      result.actionExtensionID = base::SysUTF8ToNSString(id);
      return result;
    }
    ui::CommandMap named;
    if (!commands->GetNamedCommands(id, extensions::CommandService::ACTIVE,
                                    extensions::CommandService::REGULAR, &named)) continue;
    for (const auto& [name, command] : named) {
      if (command.accelerator() != accelerator) continue;
      DeliverExtensionCommand(profile, *extension, name, page->web_contents());
      return [[CrestExtensionShortcutResult alloc] init];
    }
  }
  return nil;
}
- (NSString*)engineVersion { return base::SysUTF8ToNSString(version_info::GetVersionNumber()); }
- (void)attachUI:(id<CrestMacUI>)ui {
  CHECK(NSThread.isMainThread);
  State().ui = ui;
}
- (BOOL)installExtension:(NSString*)extensionID package:(NSString*)path profile:(NSUUID*)profileID
                  window:(NSUUID*)windowID completion:(void (^)(BOOL, NSString*))completion {
  CHECK(NSThread.isMainThread);
  const std::string id = base::SysNSStringToUTF8(extensionID);
  Profile* profile = crest::EngineBinding::Get().Profiles().Find(KeyFor(profileID));
  NSWindow* window = [UI() windowWithID:windowID];
  if (!profile || profile->IsOffTheRecord() || !window ||
      id.size() != 32 || id.find_first_not_of("abcdefghijklmnop") != std::string::npos) return NO;
  auto prompt = std::make_unique<ExtensionInstallPrompt>(profile, gfx::NativeWindow(window),
      std::make_unique<extensions::InstallPromptData>(extensions::InstallPromptData::UNSET_PROMPT_TYPE));
  prompt->SetSkipPostInstallUI(true);
  auto installer = extensions::CrxInstaller::Create(profile, std::move(prompt));
  installer->set_expected_id(id);
  installer->set_is_gallery_install(true);
  installer->set_delete_source(true);
  // Each target profile independently verifies CRX3 signature and publisher proof.
  installer->AddInstallerCallback(base::BindOnce(^(const std::optional<extensions::CrxInstallError>& error) {
    completion(!error, error ? base::SysUTF16ToNSString(error->message()) : @"");
  }));
  installer->InstallCrx(base::FilePath(base::SysNSStringToUTF8(path)));
  return YES;
}
- (void)disposePages:(NSArray<NSUUID*>*)pageIDs windows:(NSArray<NSUUID*>*)windowIDs
    releaseProfiles:(NSArray<NSUUID*>*)profileIDs {
  CHECK(NSThread.isMainThread);
  auto& state = State();
  // A Space-scoped popup is anchored in one of the windows or profiles being
  // released, and nothing else would close it.
  if (windowIDs.count || profileIDs.count) state.space_extension_popup.reset();
  for (NSUUID* identifier in pageIDs) DisposePage(KeyFor(identifier));
  for (NSUUID* identifier in windowIDs) {
    const auto id = KeyFor(identifier);
    // A sign-in window closed before its page reached the callback.
    EndAuthenticationSession(id, nil, false);
    for (;;) {
      auto owner = std::find_if(state.browsers.begin(), state.browsers.end(),
          [&](const auto& entry) { return entry.second->window == id; });
      if (owner == state.browsers.end()) break;
      Browser* browser = owner->second->browser;
      TabStripModel* strip = browser->tab_strip_model();
      if (strip->empty()) browser->SynchronouslyDestroyBrowser();
      else for (int index = strip->count() - 1; index >= 0; --index) strip->DetachAndDeleteWebContentsAt(index);
    }
  }
  auto& binding = crest::EngineBinding::Get();
  for (NSUUID* identifier in profileIDs) {
    const std::string id = KeyFor(identifier);
    Profile* profile = binding.Profiles().Find(id);
    if (!profile) continue;
    // Pages still offered to the core close with their Browsers.
    CloseBrowsers(profile);
    binding.Extensions().Forget(id);
    binding.Profiles().Release(id);
  }
}
- (void)disposePages {
  CHECK(NSThread.isMainThread);
  auto& state = State();
  state.disposing = true;
  crest::EngineBinding::Get().Dispose();
  CancelAllAuthenticationSessions();
  state.space_extension_popup.reset();
  state.pages.clear();
  // The core has stopped accepting work. Observer teardown precedes native destruction.
  while (!state.browsers.empty()) {
    Browser* browser = state.browsers.begin()->second->browser;
    TabStripModel* strip = browser->tab_strip_model();
    if (strip->empty()) {
      browser->SynchronouslyDestroyBrowser();
    } else {
      const int count = strip->count();
      for (int index = count - 1; index >= 0; --index) strip->DetachAndDeleteWebContentsAt(index);
    }
  }
  crest::EngineBinding::Get().Extensions().Clear();
  crest::EngineBinding::Get().Profiles().ReleaseAll();
}
- (void)cancelAuthenticationSessionForWindow:(NSUUID*)windowID {
  CHECK(NSThread.isMainThread);
  EndAuthenticationSession(KeyFor(windowID), nil, false);
}
- (void)completeQuit {
  State().quitting = true;
  [NSApp terminate:nil];
}
@end

namespace crest {
void SnapPictureInPictureWindow(views::Widget* widget) {
  if (!IsEnabled() || !widget) return;
  NSWindow* window = widget->GetNativeWindow().GetNativeNSWindow();
  NSScreen* screen = window.screen;
  if (!screen) return;
  constexpr CGFloat kMargin = 16;
  NSRect frame = window.frame;
  NSRect work = screen.visibleFrame;
  const CGFloat left = NSMinX(work) + kMargin;
  const CGFloat right = std::max(left, NSMaxX(work) - kMargin - NSWidth(frame));
  const CGFloat bottom = NSMinY(work) + kMargin;
  const CGFloat top = std::max(bottom, NSMaxY(work) - kMargin - NSHeight(frame));
  NSRect target = frame;
  target.origin.x = NSMidX(frame) < NSMidX(work) ? left : right;
  target.origin.y = NSMidY(frame) < NSMidY(work) ? bottom : top;
  if (std::abs(target.origin.x - frame.origin.x) < 1 &&
      std::abs(target.origin.y - frame.origin.y) < 1) return;
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
    context.duration = 0.22;
    [[window animator] setFrame:target display:YES];
  } completionHandler:nil];
}

namespace {
bool MatchesAuthenticationCallback(ASWebAuthenticationSessionRequest* request, const GURL& url) {
  NSURL* candidate = net::NSURLWithGURL(url);
  if (!candidate) return false;
  if (@available(macOS 14.4, *)) return [request.callback matchesURL:candidate];
  return request.callbackURLScheme.length &&
      [candidate.scheme caseInsensitiveCompare:request.callbackURLScheme] == NSOrderedSame;
}

class AuthenticationSessionThrottle final : public content::NavigationThrottle {
 public:
  explicit AuthenticationSessionThrottle(content::NavigationThrottleRegistry& registry)
      : NavigationThrottle(registry) {}
  const char* GetNameForLogging() override { return "CrestAuthenticationSessionThrottle"; }
  ThrottleCheckResult WillStartRequest() override { return Check(); }
  ThrottleCheckResult WillRedirectRequest() override { return Check(); }

 private:
  ThrottleCheckResult Check() {
    auto& state = State();
    auto* navigation = navigation_handle();
    if (state.authentication_sessions.empty() || state.disposing || !navigation->IsInPrimaryMainFrame())
      return PROCEED;
    Browser* browser = nullptr;
    for (const auto& [id, page] : state.pages)
      if (page->web_contents() == navigation->GetWebContents()) { browser = page->browser; break; }
    if (!browser) return PROCEED;
    for (const auto& [key, owner] : state.browsers) {
      if (owner->browser != browser) continue;
      auto session = state.authentication_sessions.find(owner->window);
      if (session == state.authentication_sessions.end() ||
          !MatchesAuthenticationCallback(session->second, navigation->GetURL())) return PROCEED;
      // Completing closes the window and destroys this navigation's page, so
      // it happens after the navigation stack has unwound.
      NSURL* callback = net::NSURLWithGURL(navigation->GetURL());
      const std::string window = owner->window;
      dispatch_async(dispatch_get_main_queue(), ^{ EndAuthenticationSession(window, callback, true); });
      return CANCEL_AND_IGNORE;
    }
    return PROCEED;
  }
};
}  // namespace

void AddNavigationThrottle(content::NavigationThrottleRegistry& registry) {
  if (!IsEnabled()) return;
  registry.AddThrottle(crest::EngineBinding::LinkThrottle(registry));
  registry.AddThrottle(std::make_unique<AuthenticationSessionThrottle>(registry));
}

bool BeginLinkDrag(content::WebContents* contents, const content::DropData& data) {
  // File, image, selection and custom payload drags retain Chromium's native path.
  // Chromium adds its own drag ID to every payload, including ordinary links.
  if (!IsEnabled() || State().disposing || data.url_infos.size() != 1 ||
      !data.url_infos[0].url.SchemeIsHTTPOrHTTPS() || data.url_infos[0].url.spec().size() > 8192 ||
      data.download_metadata || !data.filenames.empty() || !data.file_system_files.empty() ||
      !data.file_contents.empty() || data.file_contents_source_url.is_valid() ||
      std::any_of(data.custom_data.begin(), data.custom_data.end(),
          [](const auto& entry) { return entry.first != u"chromium/x-drag-id"; }) || !data.text ||
      *data.text != base::UTF8ToUTF16(data.url_infos[0].url.spec())) return false;
  auto* focused_frame = contents->GetFocusedFrame();
  if (!focused_frame || !focused_frame->GetView() ||
      !focused_frame->GetView()->GetSelectedText().empty()) return false;
  crest::EnginePage* page = crest::EngineBinding::Get().PageFor(contents);
  NSURL* url = net::NSURLWithGURL(data.url_infos[0].url);
  if (!page || page->standalone() || !url) return false;
  return [UI() beginLinkDrag:url title:base::SysUTF16ToNSString(data.url_infos[0].title)
                        page:UUIDFor(page->key())];
}


void AppendLinkMenuItem(NSMenu* menu, content::WebContents* contents, const GURL& url,
                        const std::u16string& selection) {
  if (!IsEnabled() || State().disposing) return;
  crest::EnginePage* page = crest::EngineBinding::Get().PageFor(contents);
  if (!page || page->standalone()) return;
  NSURL* link = url.SchemeIsHTTPOrHTTPS() ? net::NSURLWithGURL(url) : nil;
  NSString* const selected = base::SysUTF16ToNSString(
      std::u16string(base::TrimWhitespace(selection, base::TRIM_ALL)));
  if (!link && !selected.length) return;
  // Crest's rows go ahead of the engine's. MenuControllerCocoa identifies its
  // rows by their model indices, so rows inserted ahead of them change only
  // their native positions.
  [UI() addPageMenuItems:menu page:UUIDFor(page->key()) link:link selection:selected.length ? selected : nil];
}

// A page the core asked whether it may close answers the core.
bool CompletePageClosePreparation(content::WebContents* contents, bool proceed) {
  return crest::AnswerBeforeUnload(contents, proceed);
}
void ShowExtensionPrompt(
    std::unique_ptr<ExtensionInstallPromptShowParams> params,
    ExtensionInstallPrompt::DoneCallback callback,
    std::unique_ptr<extensions::InstallPromptData> prompt) {
  using Result = extensions::ExtensionInstallPromptClient::Result;
  using Payload = ExtensionInstallPrompt::DoneCallbackPayload;
  NSWindow* window = params->GetParentWindow().GetNativeNSWindow();
  if (!window || window.attachedSheet || params->WasParentDestroyed() || prompt->requires_parent_permission()) {
    std::move(callback).Run(Payload(Result::ABORTED));
    return;
  }
  struct PendingPrompt {
    std::unique_ptr<ExtensionInstallPromptShowParams> params;
    ExtensionInstallPrompt::DoneCallback callback;
    std::unique_ptr<extensions::InstallPromptData> prompt;
  };
  auto pending = std::make_shared<PendingPrompt>(std::move(params), std::move(callback), std::move(prompt));
  // An install a Crest window started is a question for the core, which the
  // window's own review answers.
  const auto window_id = window.identifier ? crest::ParseGuid(base::SysNSStringToUTF8(window.identifier)) : std::nullopt;
  if (window_id && pending->prompt->extension() &&
      pending->prompt->type() == extensions::InstallPromptData::INSTALL_PROMPT) {
    auto* extension = pending->prompt->extension();
    crest::engine::ExtensionInstallQuestion question{
        .extension_id = extension->id(),
        .name = extension->name(),
        .version = extension->version().GetString(),
        .can_withhold_site_access = extensions::util::CanWithholdPermissionsFromExtension(*extension),
        .withholds_site_access = pending->prompt->ShouldWithheldPermissionsOnDialogAccept()};
    if (const std::string* summary = extension->manifest()->FindStringPath("description")) question.summary = *summary;
    const auto permission_details = pending->prompt->GetPermissions();
    for (size_t i = 0; i < pending->prompt->GetPermissionCount(); ++i) {
      question.permissions.push_back(base::UTF16ToUTF8(pending->prompt->GetPermission(i)));
      if (i < permission_details.details.size() && !permission_details.details[i].empty())
        question.permissions.push_back(base::UTF16ToUTF8(permission_details.details[i]));
    }
    if (!pending->prompt->icon().IsEmpty()) {
      if (auto png = pending->prompt->icon().As1xPNGBytes(); png && png->size())
        question.icon = crest::engine::Bytes(png->data(), png->data() + png->size());
    }
    crest::EngineBinding::Get().Prompts().AskToInstall(*window_id, std::move(question),
        base::BindOnce([](std::shared_ptr<PendingPrompt> pending, bool accepted, bool withhold) {
          if (!pending->callback) return;
          Result result = Result::USER_CANCELED;
          if (pending->params->WasParentDestroyed()) result = Result::ABORTED;
          else if (accepted) { result = withhold ? Result::ACCEPTED_WITH_WITHHELD_PERMISSIONS : Result::ACCEPTED; pending->prompt->OnDialogAccepted(); }
          else pending->prompt->OnDialogCanceled();
          std::move(pending->callback).Run(Payload(result));
        }, pending));
    return;
  }
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = base::SysUTF16ToNSString(pending->prompt->GetDialogTitle());
  NSMutableArray* messages = [NSMutableArray array];
  if (pending->prompt->GetPermissionCount()) {
    [messages addObject:base::SysUTF16ToNSString(pending->prompt->GetPermissionsHeading())];
    for (size_t i = 0; i < pending->prompt->GetPermissionCount(); ++i)
      [messages addObject:base::SysUTF16ToNSString(pending->prompt->GetPermission(i))];
  }
  const bool withhold = pending->prompt->ShouldWithheldPermissionsOnDialogAccept();
  if (withhold) [messages addObject:@"Website access is withheld until you grant it in extension settings."];
  alert.informativeText = [messages componentsJoinedByString:@"\n\n"];
  NSString* accept = base::SysUTF16ToNSString(pending->prompt->GetAcceptButtonLabel());
  if (accept.length) [alert addButtonWithTitle:accept];
  [alert addButtonWithTitle:base::SysUTF16ToNSString(pending->prompt->GetAbortButtonLabel())];
  if (accept.length) {
    alert.buttons.firstObject.enabled = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      alert.buttons.firstObject.enabled = YES;
    });
  }
  id closed = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification
      object:window queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*) {
    if (alert.window.sheetParent) [alert.window.sheetParent endSheet:alert.window returnCode:NSModalResponseCancel];
  }];
  [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response) {
    [[NSNotificationCenter defaultCenter] removeObserver:closed];
    Result result = Result::USER_CANCELED;
    if (pending->params->WasParentDestroyed()) result = Result::ABORTED;
    else if (accept.length && response == NSAlertFirstButtonReturn) {
      result = withhold ? Result::ACCEPTED_WITH_WITHHELD_PERMISSIONS : Result::ACCEPTED;
      pending->prompt->OnDialogAccepted();
    } else pending->prompt->OnDialogCanceled();
    std::move(pending->callback).Run(Payload(result));
  }];
}

std::unique_ptr<permissions::PermissionPrompt> CreatePermissionPrompt(
    content::WebContents* contents, permissions::PermissionPrompt::Delegate* delegate) {
  if (delegate->ShouldDropCurrentRequestIfCannotShowQuietly()) return nullptr;
  // A request Crest's permission record covers is asked through the page, so
  // the decision is recorded per Space and listed in Privacy.
  if (auto prompt = crest::EngineBinding::Get().PermissionPrompt(contents, delegate)) return prompt;
  BrowserWindowInterface* browser = GlobalBrowserCollection::GetInstance()->FindBrowserWithTab(contents);
  NSWindow* window = browser ? WindowForBrowser(browser->GetBrowserForMigrationOnly()) : nil;
  if (!window || window.attachedSheet) return nullptr;
  return std::make_unique<NativePermissionPrompt>(window, delegate);
}
namespace {
bool HasBundleMarker(NSString* name) {
  NSString* path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:name];
  return path && [NSFileManager.defaultManager fileExistsAtPath:path];
}
// A product bundle hosts the native Crest UI for every launch, including the
// ones Crest cannot add switches to: Finder, login items, the default-browser
// role and Dock reopen. Experiment bundles keep requiring the explicit switch.
bool IsProductBundle() {
  static const bool product = HasBundleMarker(@"Crest-Native-Host");
  return product;
}
}  // namespace
bool IsEnabled() {
  static const bool enabled =
      IsProductBundle() || base::CommandLine::ForCurrentProcess()->HasSwitch("crest-control-plane");
  return enabled;
}
void OnBrowserWindowCreated(Browser* browser) {
  if (!State().bootstrap) {
    State().bootstrap = browser;
    crest::EngineBinding::Get().Profiles().SetRoot(browser->GetProfile()->GetOriginalProfile());
  }
  if (!State().started || !State().creating_window.empty()) return;
  if (RegisterEngineBrowser(browser)) return;
  // `CanCreateEngineBrowser` refuses these before they are created, so this is
  // only reached by a creation path that does not consult it. The Browser is
  // still tracked so its tabs are offered and then declined, rather than left
  // running unowned.
  const std::string key = "native/" + base::Uuid::GenerateRandomV4().AsLowercaseString();
  State().browsers.emplace(key, std::make_unique<BrowserOwner>(browser, std::string()));
}
void OnBrowserWindowDestroyed(Browser* browser) {
  if (State().bootstrap == browser) State().bootstrap = nullptr;
  std::erase_if(State().browsers, [browser](const auto& pair) { return pair.second->browser == browser; });
}
void EnsureCrestUIStarted(Browser* browser) {
  CHECK(NSThread.isMainThread);
  if (State().started) return;
  // An experiment bundle must name its own engine profile root. A product
  // bundle uses Chromium's default directory for its own bundle identity.
  CHECK(IsProductBundle() || base::CommandLine::ForCurrentProcess()->HasSwitch("user-data-dir"));
  // The review and product compositions keep separate framework names so a
  // package can only ever contain the one it was assembled from.
  NSBundle* bundle = nil;
  for (NSString* name in @[ @"CrestChromiumUI.framework", @"CrestChromiumUIProduct.framework" ]) {
    NSString* path = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:name];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) continue;
    bundle = [NSBundle bundleWithPath:path];
    break;
  }
  CHECK(bundle);
  NSError* error = nil;
  CHECK([bundle loadAndReturnError:&error]) << base::SysNSStringToUTF8(error.description);
  // The framework's one entry point. It registers the binding with the core
  // the framework creates, and keeps the shell for what only AppKit does.
  base::apple::ScopedCFTypeRef<CFBundleRef> framework(
      CFBundleCreate(kCFAllocatorDefault, base::apple::NSToCFPtrCast(bundle.bundleURL)));
  auto start = reinterpret_cast<CrestChromiumUIStart>(
      CFBundleGetFunctionPointerForName(framework.get(), CFSTR("crest_chromium_ui_start")));
  CHECK(start);
  State().started = true;
  static base::NoDestructor<MacShell> shell;
  auto& binding = crest::EngineBinding::Get();
  binding.SetShell(shell.get());
  const crest_engine_binding_t table = binding.Table();
  const crest_engine_pages_t pages = binding.Pages();
  const auto& fingerprint = crest::EngineBinding::Fingerprint();
  start([[CrestChromiumMacShell alloc] init], &table, fingerprint.data(), fingerprint.size(), &pages);
  auto pending = std::move(State().pending_authentication_sessions);
  State().pending_authentication_sessions.clear();
  for (ASWebAuthenticationSessionRequest* request : pending) StartAuthenticationSession(request);
}
id<CrestMacUI> MacUI() {
  return UI();
}
void OnEngineWindowShown(Browser* browser, bool focused) {
  if (!State().started) return;
  for (const auto& [key, owner] : State().browsers) {
    if (owner->browser != browser || !owner->engine_window || owner->presented) continue;
    // `chrome.windows.create` with `focused: false` reaches ShowInactive().
    owner->focused = focused;
    return;
  }
}
bool CanCreateEngineBrowser(Profile* profile) {
  // Before the core runs, and for the window the core is creating for itself,
  // the engine's own answer stands.
  if (!IsEnabled() || !State().started || !State().creating_window.empty()) return true;
  if (State().disposing || State().quitting) return true;
  const auto& profiles = crest::EngineBinding::Get().Profiles();
  const std::string profile_id = profiles.IdFor(profile);
  if (profile_id.empty() || profiles.IsDeleting(profile_id)) return false;
  NSUUID* space_profile = UUIDFor(profile_id);
  if (!space_profile || ![UI() reserveEngineWindowForProfile:space_profile ownWindow:YES]) return false;
  // The Browser is created in this same turn; a creation that fails leaves
  // nothing to hand the window to.
  State().own_window_profile = profile;
  base::SequencedTaskRunner::GetCurrentDefault()->PostTask(
      FROM_HERE, base::BindOnce([] { State().own_window_profile = nullptr; }));
  return true;
}
NSWindow* WindowForBrowser(Browser* browser) {
  if (!State().started) return nil;
  for (const auto& [key, owner] : State().browsers) {
    if (owner->browser != browser || owner->window.empty()) continue;
    // A reserved engine window has an identifier before it has a window: a
    // renderer popup never opens the one reserved for it, because its tab is
    // adopted into the opener's window. Those Browsers keep the same fallback
    // they had before they carried an identifier at all.
    if (NSWindow* window = [UI() windowWithID:UUIDFor(owner->window)]) return window;
    break;
  }
  if (!State().creating_window.empty()) return [UI() windowWithID:UUIDFor(State().creating_window)];
  return [UI() windowWithID:nil];
}
bool DeferQuit() {
  return IsEnabled() && State().started && !State().quitting && [UI() deferQuit];
}
bool Reopen() {
  if (!IsEnabled() || !State().started || State().disposing || State().quitting) return false;
  return [UI() reopen];
}
bool OpenExternalURLs(NSArray<NSURL*>* urls) {
  // Before the native root exists there is nothing to route into, and after a
  // quit has been accepted there is nothing left to open. Chromium then keeps
  // its own behavior rather than dropping the request.
  if (!IsEnabled() || !State().started || State().disposing || State().quitting) return false;
  return [UI() openExternalURLs:urls];
}
bool BeginAuthenticationSession(ASWebAuthenticationSessionRequest* request) {
  CHECK(NSThread.isMainThread);
  if (!IsEnabled()) return false;
  if (!State().started) { State().pending_authentication_sessions.push_back(request); return true; }
  StartAuthenticationSession(request);
  return true;
}
bool CancelAuthenticationSession(ASWebAuthenticationSessionRequest* request) {
  CHECK(NSThread.isMainThread);
  if (!IsEnabled()) return false;
  auto& state = State();
  auto pending = std::find_if(state.pending_authentication_sessions.begin(),
      state.pending_authentication_sessions.end(),
      [&](ASWebAuthenticationSessionRequest* candidate) { return [candidate.UUID isEqual:request.UUID]; });
  if (pending != state.pending_authentication_sessions.end()) {
    state.pending_authentication_sessions.erase(pending);
    [request cancelWithError:[NSError errorWithDomain:ASWebAuthenticationSessionErrorDomain
                                                 code:ASWebAuthenticationSessionErrorCodeCanceledLogin
                                             userInfo:nil]];
    return true;
  }
  for (const auto& [window, candidate] : state.authentication_sessions) {
    if (![candidate.UUID isEqual:request.UUID]) continue;
    EndAuthenticationSession(std::string(window), nil, true);
    break;
  }
  return true;
}
void TranslateSelection(const std::u16string& text) {
  if (!IsEnabled() || !State().started || State().disposing || text.empty()) return;
  [UI() translateText:base::SysUTF16ToNSString(text)];
}
void ShowEngineNotice(const std::u16string& message, const std::string& symbol) {
  if (!IsEnabled() || !State().started || State().disposing || message.empty()) return;
  // TRANSITIONAL until the toast hunk passes its ToastId: the hook still names
  // the SF Symbol Chromium's link-copied toast used.
  [UI() showEngineNotice:base::SysUTF16ToNSString(message)
                    kind:symbol == "link" ? CrestEngineNoticeKindLinkCopied : CrestEngineNoticeKindConfirmation];
}
}  // namespace crest
