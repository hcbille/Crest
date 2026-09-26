#ifndef CHROME_BROWSER_UI_CREST_CREST_ENGINE_BINDING_H_
#define CHROME_BROWSER_UI_CREST_CREST_ENGINE_BINDING_H_

#include <array>
#include <cstdint>
#include <deque>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <vector>

#include "base/functional/callback_forward.h"
#include "base/memory/raw_ptr.h"
#include "base/memory/raw_ptr_exclusion.h"
#include "base/memory/weak_ptr.h"
#include "base/no_destructor.h"
#include "chrome/browser/ui/crest/crest_engine.h"
#include "chrome/browser/ui/crest/crest_engine_contract.h"
#include "components/permissions/permission_prompt.h"

class GURL;
class Profile;

namespace content {
class WebContents;
}

namespace crest {

class EngineDownloads;
class EngineExtensions;
class EnginePage;
class EngineProfiles;
class EnginePrompts;

// Chromium's engine binding: the portable half of Crest's Chromium host, in
// C++ and Chromium's own types with no Objective-C, so it serves every
// platform. It implements crest_engine.h. The core hands it commands through
// the table's `run` and it reports what the engine does with each page
// straight to the core, through the function `attach` gave it. Each
// platform's shell embeds the pages' views and does what only the operating
// system can.
//
// The platform reaches the binding directly through a second table,
// crest_engine_pages_t: it asks a page's engine for view work with a
// PageRequest, answered at once, and hears what finishes later, such as a
// find's count or an export, as an EnginePresentation.
//
// Everything runs on Chromium's UI thread. The core delivers the commands a
// report causes before the report returns, and a command such as ClosePage
// must never destroy a WebContents inside one of its own observers, so no
// report is made on the stack of a Chromium callback: reports and
// presentations queue, and one task posted to the UI thread sends them in
// order. A page's snapshot is sent last in the turn in which it changed.
class EngineBinding {
 public:
  // What the platform shell still does for the binding. TRANSITIONAL: the
  // shell keeps the Browsers until they move into the binding.
  class Shell {
   public:
    virtual ~Shell() = default;
    // Creates `page`'s WebContents in `profile`, which `profile_id` names,
    // inside the Browser of `window`, and answers it, or nullptr when it
    // cannot.
    virtual content::WebContents* CreateContents(const std::string& page,
                                                 Profile* profile,
                                                 const std::string& profile_id,
                                                 const std::string& window) = 0;
    // Makes the WebContents the engine offered as `token` the page, when it is
    // in `profile`, and answers it, or nullptr when the offer is gone.
    virtual content::WebContents* AdoptContents(const std::string& page,
                                                const std::string& token,
                                                const std::string& profile) = 0;
    // The page the engine offered as `token` has no place in Crest; it closes.
    // TRANSITIONAL until engine-offered pages move to the core (WP C (l)).
    virtual bool RejectAdoption(const std::string& token) = 0;
    // Destroys `page`'s WebContents, which the binding has let go of.
    virtual void DestroyContents(const std::string& page) = 0;
    // Loads the link navigation staged as `token` in `page`, which is heading
    // to `url`. TRANSITIONAL until link routing moves into the core (WP C (l)).
    virtual bool LoadStagedNavigation(const std::string& page, const std::string& token, const GURL& url) = 0;
    virtual void DiscardStagedNavigation(const std::string& token) = 0;
    // Moves `page`'s WebContents into the Browser of `window`. TRANSITIONAL
    // until the Browsers move into the binding.
    virtual bool MoveToWindow(const std::string& page, const std::string& window) = 0;
    // Hosts the view of the inspector docked on `page`, or none when
    // `frontend` is null.
    virtual void DockInspector(const std::string& page, content::WebContents* frontend) = 0;
    // Closes the pages and Browsers of the profiles being let go of.
    virtual void ReleaseProfiles(const std::set<std::string>& profiles) = 0;
    // Closes the side panels the shell hosts for `extension` in `profile`'s
    // pages, or only for the tab `tab` names.
    virtual void RetractSidePanels(Profile* profile, const std::string& extension, std::optional<int> tab) = 0;
  };

  static EngineBinding& Get();

  EngineBinding(const EngineBinding&) = delete;
  EngineBinding& operator=(const EngineBinding&) = delete;

  // The function table the platform registers with the core, the engine
  // contract the binding was built against, which the core checks, and the
  // platform's direct path to the binding.
  crest_engine_binding_t Table();
  static const std::array<uint8_t, 32>& Fingerprint();
  crest_engine_pages_t Pages();

  void SetShell(Shell* shell);
  // The engine is shutting down: nothing more is reported, and every page is
  // let go of without a report.
  void Dispose();

  // What the platform asks of a page directly that no PageRequest carries
  // yet. TRANSITIONAL until engine-offered pages and link routing move
  // (WP C (l)).
  bool Adopt(const std::string& page, const std::string& token);
  bool Stage(const std::string& page, const std::string& token, const std::string& url);
  void Load(const std::string& page, const std::string& url);

  // The page that follows `contents`, for the engine's own hooks, or nullptr
  // when no page does.
  EnginePage* PageFor(content::WebContents* contents);
  // The engine's extensions changed, which Chrome Web Store listings show.
  void RefreshStoreListings();
  // The shell hosts the view of the inspector docked on `page`, or none.
  void DockInspector(const std::string& page, content::WebContents* frontend);
  // The engine profiles, and every profile's extensions.
  EngineProfiles& Profiles();
  EngineExtensions& Extensions();
  // The engine's downloads in Crest's profiles.
  EngineDownloads& Downloads();
  bool disposing() const { return disposing_; }
  // The regular profile a private window's pages derive from, which the
  // window names when it opens. TRANSITIONAL: which profile it is is a rule
  // for the core.
  void SetPrivateSourceProfile(const std::string& profile);
  // What the binding's pages ask the person.
  EnginePrompts& Prompts();
  // The prompt for a permission request in the page that shows `contents`,
  // or nullptr when no page shows it or Crest's record does not cover it.
  std::unique_ptr<permissions::PermissionPrompt> PermissionPrompt(
      content::WebContents* contents,
      permissions::PermissionPrompt::Delegate* delegate);
  // The engine asks for an extension's side panel beside `page`.
  void RequestSidePanel(const std::string& page, const std::string& extension, engine::SidePanelRequest request);

  // For the binding's pages.
  void Report(engine::EngineEvent event);
  void Present(engine::EnginePresentation presentation);
  void ReportStateSoon(const std::string& page);
  void PageLost(const std::string& page);
  bool LoadStagedNavigation(const std::string& page, const std::string& token, const GURL& url);
  void DiscardStagedNavigation(const std::string& token);

 private:
  friend class base::NoDestructor<EngineBinding>;

  EngineBinding();
  ~EngineBinding();

  // What the binding sends once the turn ends: a report to the core or a
  // presentation to the platform, encoded.
  struct Outgoing {
    bool to_core;
    std::vector<uint8_t> message;
  };

  static void CREST_CALL Attach(void* context, uint64_t app, uint64_t engine, crest_engine_report_t report);
  static void CREST_CALL Run(void* context, const uint8_t* command, size_t length);
  static crest_status_t CREST_CALL Request(void* context, const uint8_t* request, size_t length, crest_buffer_t* out);
  static void CREST_CALL Release(void* context, crest_buffer_t* buffer);
  static void CREST_CALL PresentTo(void* context, crest_engine_present_t present, void* ui);

  // Each request, handled where it lands.
  bool Handle(const engine::GoToHistoryOffset& request);
  bool Handle(const engine::ReloadPage& request);
  bool Handle(const engine::StopLoading& request);
  bool Handle(const engine::ZoomPage& request);
  bool Handle(const engine::FindInPage& request);
  bool Handle(const engine::CapturePage& request);
  bool Handle(const engine::ExportPage& request);
  engine::InteractionState Handle(const engine::SaveInteractionState& request);
  bool Handle(const engine::RestoreInteractionState& request);
  bool Handle(const engine::MovePageToWindow& request);
  bool Handle(const engine::ShowPage& request);
  bool Handle(const engine::HidePage& request);
  engine::PageIconImage Handle(const engine::PageIcon& request);
  bool Handle(const engine::OpenStandalonePage& request);
  bool Handle(const engine::CloseStandalonePage& request);
  bool Handle(const engine::WatchPage& request);
  engine::PageMediaState Handle(const engine::PageMedia& request);
  bool Handle(const engine::EnterPictureInPicture& request);
  bool Handle(const engine::ActivateMediaSession& request);
  bool Handle(const engine::PerformMediaAction& request);
  bool Handle(const engine::MuteMediaSession& request);
  bool Handle(const engine::AnswerInfoBar& request);
  bool Handle(const engine::RefreshPageIcon& request);
  bool Handle(const engine::ShowBlockedPopups& request);
  bool Handle(const engine::AddContentScript& request);
  bool Handle(const engine::EvaluateContentScript& request);
  bool Handle(const engine::RefreshStoreListing& request);
  bool Handle(const engine::OpenInspector& request);
  bool Handle(const engine::CloseInspector& request);
  bool Handle(const engine::PageInspected& request);
  engine::InspectorLayout Handle(const engine::LayoutInspector& request);
  engine::ExtensionActionList Handle(const engine::PageExtensions& request);
  engine::ExtensionActionList Handle(const engine::PinnedExtensions& request);
  engine::InstalledExtensionList Handle(const engine::InstalledExtensions& request);
  bool Handle(const engine::ChangeExtension& request);
  bool Handle(const engine::HasSidePanel& request);
  engine::CertificateChain Handle(const engine::PageCertificates& request);
  bool Handle(const engine::ClearSiteData& request);
  bool Handle(const engine::SetSitePermission& request);
  bool Handle(const engine::PrepareProfile& request);
  bool Handle(const engine::DeleteProfile& request);
  bool Handle(const engine::AdoptOfferedPage& request);
  bool Handle(const engine::RejectOfferedPage& request);
  bool Handle(const engine::AnswerEngineDownloadDestination& request);
  bool Handle(const engine::CancelEngineDownload& request);
  bool Handle(const engine::RemoveEngineDownload& request);
  bool Handle(const engine::ApproveEngineDownload& request);

  void Perform(engine::EngineCommand command);
  std::vector<uint8_t> Answer(const engine::PageRequest& request);
  void Create(const engine::CreatePage& creation, bool standalone);
  void CreateNow(const std::string& page);
  void ProfileLoaded(const std::string& page, Profile* profile);
  void Created(const std::string& page, content::WebContents* contents);
  void Live(EnginePage& page, content::WebContents* contents);
  void Close(const engine::ClosePage& closing);
  void Forget(const std::string& page);
  void ScheduleFlush();
  void Flush();
  EnginePage* Find(const std::string& page);

  raw_ptr<Shell> shell_ = nullptr;
  uint64_t app_ = 0;
  uint64_t engine_ = 0;
  crest_engine_report_t report_ = nullptr;
  crest_engine_present_t present_ = nullptr;
  // The platform's own, handed back with each presentation.
  RAW_PTR_EXCLUSION void* ui_ = nullptr;
  bool disposing_ = false;
  std::map<std::string, std::unique_ptr<EnginePage>> pages_;
  // The pages the engine could not create, until the core closes them, so a
  // platform that comes to one late still hears it has no view.
  std::set<std::string> failed_;
  std::unique_ptr<EngineProfiles> profiles_;
  std::string private_source_;
  std::unique_ptr<EngineExtensions> extensions_;
  std::unique_ptr<EngineDownloads> downloads_;
  std::unique_ptr<EnginePrompts> prompts_;
  std::deque<Outgoing> queue_;
  std::vector<std::string> due_;
  bool flush_posted_ = false;
  bool flushing_ = false;
  base::WeakPtrFactory<EngineBinding> weak_factory_{this};
};

// A GUID as the platform spells it: uppercase hexadecimal in RFC 4122 groups.
std::string GuidText(const engine::Guid& guid);
// The GUID `text` spells in RFC 4122 groups, in either case, or nothing.
std::optional<engine::Guid> ParseGuid(const std::string& text);

}  // namespace crest

#endif  // CHROME_BROWSER_UI_CREST_CREST_ENGINE_BINDING_H_
