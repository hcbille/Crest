#include "chrome/browser/ui/crest/crest_engine_binding.h"

#include <algorithm>
#include <cstring>
#include <type_traits>
#include <utility>
#include <variant>

#include "base/check.h"
#include "base/functional/bind.h"
#include "base/location.h"
#include "base/task/sequenced_task_runner.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/ui/crest/crest_chrome_hooks.h"
#include "chrome/browser/ui/crest/crest_download_hooks.h"
#include "chrome/browser/download/download_confirmation_result.h"
#include "ui/shell_dialogs/selected_file_info.h"
#include "chrome/browser/ui/crest/crest_engine_downloads.h"
#include "chrome/browser/ui/crest/crest_engine_extensions.h"
#include "chrome/browser/ui/crest/crest_engine_page.h"
#include "chrome/browser/ui/crest/crest_engine_profiles.h"
#include "chrome/browser/ui/crest/crest_engine_prompts.h"
#include "net/base/auth.h"
#include "content/public/browser/browser_task_traits.h"
#include "content/public/browser/browser_thread.h"
#include "content/public/browser/download_item_utils.h"
#include "content/public/browser/web_contents.h"
#include "url/gurl.h"

namespace crest {

std::string GuidText(const engine::Guid& guid) {
  static constexpr char kDigits[] = "0123456789ABCDEF";
  std::string text;
  text.reserve(36);
  for (size_t index = 0; index < guid.size(); ++index) {
    if (index == 4 || index == 6 || index == 8 || index == 10) {
      text.push_back('-');
    }
    text.push_back(kDigits[guid[index] >> 4]);
    text.push_back(kDigits[guid[index] & 0x0f]);
  }
  return text;
}

std::optional<engine::Guid> ParseGuid(const std::string& text) {
  engine::Guid guid{};
  size_t digits = 0;
  for (size_t index = 0; index < text.size(); ++index) {
    const char character = text[index];
    if (index == 8 || index == 13 || index == 18 || index == 23) {
      if (character != '-') {
        return std::nullopt;
      }
      continue;
    }
    int value;
    if (character >= '0' && character <= '9') {
      value = character - '0';
    } else if (character >= 'a' && character <= 'f') {
      value = character - 'a' + 10;
    } else if (character >= 'A' && character <= 'F') {
      value = character - 'A' + 10;
    } else {
      return std::nullopt;
    }
    if (digits >= 32) {
      return std::nullopt;
    }
    guid[digits / 2] = static_cast<uint8_t>(guid[digits / 2] | (digits % 2 ? value : value << 4));
    ++digits;
  }
  if (digits != 32 || text.size() != 36) {
    return std::nullopt;
  }
  return guid;
}

// static
EngineBinding& EngineBinding::Get() {
  static base::NoDestructor<EngineBinding> binding;
  return *binding;
}

EngineBinding::EngineBinding() = default;
EngineBinding::~EngineBinding() = default;

crest_engine_binding_t EngineBinding::Table() {
  return crest_engine_binding_t{this, &EngineBinding::Attach, &EngineBinding::Run};
}

// static
const std::array<uint8_t, 32>& EngineBinding::Fingerprint() {
  return engine::kFingerprint;
}

crest_engine_pages_t EngineBinding::Pages() {
  return crest_engine_pages_t{this, &EngineBinding::Request, &EngineBinding::Release, &EngineBinding::PresentTo};
}

void EngineBinding::SetShell(Shell* shell) {
  shell_ = shell;
}

void EngineBinding::Dispose() {
  disposing_ = true;
  queue_.clear();
  due_.clear();
  extensions_.reset();
  prompts_.reset();
  downloads_.reset();
  // The shell lets the profiles go once its Browsers are gone.
  Profiles().Dispose();
  for (auto& [key, page] : pages_) {
    page->Stop();
  }
  pages_.clear();
}

// The core's side.

// static
void CREST_CALL EngineBinding::Attach(void* context, uint64_t app, uint64_t engine, crest_engine_report_t report) {
  auto* binding = static_cast<EngineBinding*>(context);
  binding->app_ = app;
  binding->engine_ = engine;
  binding->report_ = report;
}

// static
void CREST_CALL EngineBinding::Run(void* context, const uint8_t* command, size_t length) {
  auto decoded = engine::Decode<engine::EngineCommand>(command, length);
  // The core and this binding registered against one engine contract, so a
  // command that does not decode is a build bug.
  CHECK(decoded) << "The core's engine command does not decode. Rebuild the engine.";
  auto* binding = static_cast<EngineBinding*>(context);
  // The core delivers on the thread that sent the intent or report that
  // caused a command, which is the UI thread; anything else waits for it.
  if (!content::BrowserThread::CurrentlyOn(content::BrowserThread::UI)) {
    content::GetUIThreadTaskRunner({})->PostTask(
        FROM_HERE, base::BindOnce(&EngineBinding::Perform, binding->weak_factory_.GetWeakPtr(), std::move(*decoded)));
    return;
  }
  binding->Perform(std::move(*decoded));
}

void EngineBinding::Perform(engine::EngineCommand command) {
  if (disposing_) {
    return;
  }
  if (const auto* creation = std::get_if<engine::CreatePage>(&command)) {
    Create(*creation, /*standalone=*/false);
  } else if (const auto* loading = std::get_if<engine::LoadPage>(&command)) {
    Load(GuidText(loading->page_id), loading->url);
  } else if (const auto* closing = std::get_if<engine::ClosePage>(&command)) {
    Close(*closing);
  } else if (const auto* recovery = std::get_if<engine::RecoverPage>(&command)) {
    if (EnginePage* page = Find(GuidText(recovery->page_id))) {
      page->Recover();
    }
  } else if (const auto* check = std::get_if<engine::CheckBeforeUnload>(&command)) {
    if (EnginePage* page = Find(GuidText(check->page_id))) {
      page->CheckBeforeUnload();
    } else {
      // A page the binding no longer holds has nothing to keep.
      Report(engine::BeforeUnloadAnswered{.page_id = check->page_id, .proceeds = true});
    }
  } else if (const auto* dialog = std::get_if<engine::SettleScriptDialog>(&command)) {
    Prompts().Settle(*dialog);
  } else if (const auto* authentication = std::get_if<engine::SettleAuthentication>(&command)) {
    Prompts().Settle(*authentication);
  } else if (const auto* permission = std::get_if<engine::SettlePermission>(&command)) {
    Prompts().Settle(*permission);
  } else if (const auto* install = std::get_if<engine::SettleExtensionInstall>(&command)) {
    Prompts().Settle(*install);
  } else if (const auto* destination = std::get_if<engine::SettleDownloadDestination>(&command)) {
    Downloads().Settle(*destination);
  } else if (const auto* cancellation = std::get_if<engine::CancelEngineDownload>(&command)) {
    Downloads().Cancel(*cancellation);
  } else if (const auto* removal = std::get_if<engine::RemoveEngineDownload>(&command)) {
    Downloads().Remove(*removal);
  } else if (const auto* approval = std::get_if<engine::ApproveEngineDownload>(&command)) {
    Downloads().Approve(*approval);
  } else if (const auto* erasing = std::get_if<engine::EraseProfileData>(&command)) {
    Erase(*erasing);
  } else if (const auto* clearing = std::get_if<engine::EraseSiteData>(&command)) {
    Erase(*clearing);
  }
}

// Creates the page's WebContents on a task of its own: the command arrives
// on the stack of whatever opened the page, and a page the engine offered
// may still claim it as its own first.
void EngineBinding::Create(const engine::CreatePage& creation, bool standalone) {
  const std::string key = GuidText(creation.page_id);
  if (pages_.contains(key)) {
    if (!standalone) {
      Report(engine::PageCreationFailed{.page_id = creation.page_id});
    }
    return;
  }
  EnginePage& page = *pages_.emplace(key, std::make_unique<EnginePage>(*this, creation, standalone)).first->second;
  // A tab's page the core unloaded comes back with the history it had,
  // restored once the page exists.
  if (creation.restore_state) {
    page.Restore(creation.restore_state->state, creation.restore_state->url);
  }
  base::SequencedTaskRunner::GetCurrentDefault()->PostTask(
      FROM_HERE, base::BindOnce(&EngineBinding::CreateNow, weak_factory_.GetWeakPtr(), key));
}

void EngineBinding::CreateNow(const std::string& key) {
  EnginePage* page = Find(key);
  if (!page || page->phase() != EnginePage::Phase::kCreating || !shell_ || disposing_) {
    return;
  }
  Profiles().Load(page->profile(), page->is_private(), private_source_,
                  base::BindOnce(&EngineBinding::ProfileLoaded, weak_factory_.GetWeakPtr(), key));
}

// The page's profile loaded, or could not: a page that closed, or became an
// offered one, meanwhile gets nothing.
void EngineBinding::ProfileLoaded(const std::string& key, Profile* profile) {
  EnginePage* page = Find(key);
  if (!page || page->phase() != EnginePage::Phase::kCreating || !shell_ || disposing_) {
    return;
  }
  Created(key, profile ? shell_->CreateContents(key, profile, page->profile(), page->window()) : nullptr);
}

void EngineBinding::Created(const std::string& key, content::WebContents* contents) {
  EnginePage* page = Find(key);
  if (!page || page->phase() != EnginePage::Phase::kCreating) {
    // The page closed, or became an offered one, while its profile loaded.
    if (contents && shell_) {
      shell_->DestroyContents(key);
    }
    return;
  }
  if (!contents) {
    const engine::Guid id = page->id();
    const bool standalone = page->standalone();
    pages_.erase(key);
    failed_.insert(key);
    Present(engine::PageViewUnavailable{.page_id = id});
    if (!standalone) {
      Report(engine::PageCreationFailed{.page_id = id});
    }
    return;
  }
  Live(*page, contents);
}

bool EngineBinding::Adopt(const std::string& key, const std::string& token) {
  EnginePage* page = Find(key);
  if (!page || page->phase() != EnginePage::Phase::kCreating || !shell_ || disposing_) {
    return false;
  }
  page->set_phase(EnginePage::Phase::kAdopting);
  content::WebContents* contents = shell_->AdoptContents(key, token, page->profile());
  if (!contents) {
    page->set_phase(EnginePage::Phase::kCreating);
    return false;
  }
  Live(*page, contents);
  return true;
}

// The page has its WebContents: the platform hears its view is ready, the
// core hears the page is live, and then it loads what it was asked to.
void EngineBinding::Live(EnginePage& page, content::WebContents* contents) {
  page.Start(contents);
  if (!page.standalone()) {
    Report(engine::PageCreated{.page_id = page.id()});
  }
  page.LoadPending();
}

// A page closed keeping its state hands the core what brings it back.
void EngineBinding::Close(const engine::ClosePage& closing) {
  const std::string key = GuidText(closing.page_id);
  std::optional<engine::PageRestoreState> restore_state;
  if (auto page = pages_.extract(key)) {
    if (closing.keeps_state) {
      restore_state = page.mapped()->RestoreState();
    }
    if (auto token = page.mapped()->TakeStagedToken()) {
      DiscardStagedNavigation(*token);
    }
    page.mapped()->Stop();
  }
  failed_.erase(key);
  std::erase(due_, key);
  if (prompts_) {
    prompts_->Forget(closing.page_id);
  }
  if (shell_) {
    shell_->DestroyContents(key);
  }
  Report(engine::PageClosed{.page_id = closing.page_id, .restore_state = std::move(restore_state)});
}

void EngineBinding::PageLost(const std::string& key) {
  EnginePage* page = Find(key);
  if (!page) {
    return;
  }
  // The engine closed the page on its own, as `window.close()` does. The
  // page is still inside its own teardown, so it is let go of afterwards.
  if (!page->standalone()) {
    Report(engine::PageClosed{.page_id = page->id(), .restore_state = std::nullopt});
  }
  base::SequencedTaskRunner::GetCurrentDefault()->PostTask(
      FROM_HERE, base::BindOnce(&EngineBinding::Forget, weak_factory_.GetWeakPtr(), key));
}

void EngineBinding::Forget(const std::string& key) {
  EnginePage* page = Find(key);
  if (!page || page->phase() != EnginePage::Phase::kGone) {
    return;
  }
  if (auto token = page->TakeStagedToken()) {
    DiscardStagedNavigation(*token);
  }
  std::erase(due_, key);
  pages_.erase(key);
}

// The platform's side.

bool EngineBinding::Stage(const std::string& key, const std::string& token, const std::string& url) {
  EnginePage* page = Find(key);
  return page && page->Stage(token, url);
}

void EngineBinding::Load(const std::string& key, const std::string& url) {
  if (EnginePage* page = Find(key)) {
    page->Load(url);
  }
}

EnginePage* EngineBinding::PageFor(content::WebContents* contents) {
  if (!contents || disposing_) {
    return nullptr;
  }
  for (auto& [key, page] : pages_) {
    if (page->web_contents() == contents) {
      return page.get();
    }
  }
  return nullptr;
}

void EngineBinding::RefreshStoreListings() {
  if (disposing_) {
    return;
  }
  for (auto& [key, page] : pages_) {
    page->RefreshStore();
  }
}

void EngineBinding::DockInspector(const std::string& key, content::WebContents* frontend) {
  if (shell_ && !disposing_) {
    shell_->DockInspector(key, frontend);
  }
}

EngineDownloads& EngineBinding::Downloads() {
  if (!downloads_) {
    downloads_ = std::make_unique<EngineDownloads>(
        Profiles(), base::BindRepeating(&EngineBinding::Report, base::Unretained(this)),
        base::BindRepeating(
            [](EngineBinding* binding, download::DownloadItem* item) -> std::optional<engine::Guid> {
              EnginePage* page = binding->PageFor(content::DownloadItemUtils::GetWebContents(item));
              return page ? std::optional<engine::Guid>(page->id()) : std::nullopt;
            },
            base::Unretained(this)));
  }
  return *downloads_;
}

EngineProfiles& EngineBinding::Profiles() {
  if (!profiles_) {
    profiles_ = std::make_unique<EngineProfiles>();
  }
  return *profiles_;
}

void EngineBinding::SetPrivateSourceProfile(const std::string& profile) {
  private_source_ = profile;
}

EngineExtensions& EngineBinding::Extensions() {
  if (!extensions_) {
    extensions_ = std::make_unique<EngineExtensions>(
        base::BindRepeating(&EngineBinding::Present, base::Unretained(this)),
        base::BindRepeating(
            [](EngineBinding* binding, Profile* profile, const std::string& extension, std::optional<int> tab) {
              if (binding->shell_ && !binding->disposing_) {
                binding->shell_->RetractSidePanels(profile, extension, tab);
              }
            },
            base::Unretained(this)),
        base::BindRepeating(&EngineBinding::RefreshStoreListings, base::Unretained(this)));
  }
  return *extensions_;
}

EnginePrompts& EngineBinding::Prompts() {
  if (!prompts_) {
    prompts_ = std::make_unique<EnginePrompts>(base::BindRepeating(&EngineBinding::Report, base::Unretained(this)));
  }
  return *prompts_;
}

std::unique_ptr<permissions::PermissionPrompt> EngineBinding::PermissionPrompt(
    content::WebContents* contents,
    permissions::PermissionPrompt::Delegate* delegate) {
  EnginePage* page = PageFor(contents);
  return page ? Prompts().Prompt(page->id(), delegate) : nullptr;
}

void EngineBinding::RequestSidePanel(const std::string& key,
                                     const std::string& extension,
                                     engine::SidePanelRequest request) {
  if (EnginePage* page = Find(key)) {
    Present(engine::SidePanelRequested{.page_id = page->id(), .extension_id = extension, .request = request});
  }
}

// The platform shows the link is gone rather than retry it as a bare address,
// which would lose the initiating frame's security and referrer.
bool EngineBinding::LoadStagedNavigation(const std::string& key, const std::string& token, const GURL& url) {
  const bool loaded = shell_ && shell_->LoadStagedNavigation(key, token, url);
  if (!loaded) {
    if (EnginePage* page = Find(key)) {
      page->StagedLinkUnavailable();
    }
  }
  return loaded;
}

void EngineBinding::DiscardStagedNavigation(const std::string& token) {
  if (shell_) {
    shell_->DiscardStagedNavigation(token);
  }
}

// The platform's direct path.

// static
crest_status_t CREST_CALL EngineBinding::Request(void* context, const uint8_t* request, size_t length,
                                                 crest_buffer_t* out) {
  if (!out) {
    return CREST_INVALID_ARGUMENT;
  }
  *out = crest_buffer_t{nullptr, 0};
  auto decoded = engine::Decode<engine::PageRequest>(request, length);
  if (!decoded) {
    return CREST_INVALID_MESSAGE;
  }
  const std::vector<uint8_t> answer = static_cast<EngineBinding*>(context)->Answer(*decoded);
  out->bytes = new uint8_t[answer.size()];
  out->length = answer.size();
  std::memcpy(out->bytes, answer.data(), answer.size());
  return CREST_OK;
}

// static
void CREST_CALL EngineBinding::Release(void*, crest_buffer_t* buffer) {
  if (!buffer) {
    return;
  }
  delete[] buffer->bytes;
  *buffer = crest_buffer_t{nullptr, 0};
}

// static
void CREST_CALL EngineBinding::PresentTo(void* context, crest_engine_present_t present, void* ui) {
  auto* binding = static_cast<EngineBinding*>(context);
  binding->present_ = present;
  binding->ui_ = ui;
}

// Hands each request to its own handler, which answers with the type the
// contract names for it.
std::vector<uint8_t> EngineBinding::Answer(const engine::PageRequest& request) {
  return std::visit(
      [this](const auto& message) {
        using Message = std::decay_t<decltype(message)>;
        auto answer = Handle(message);
        static_assert(std::is_same_v<decltype(answer), typename engine::PageRequestAnswer<Message>::Type>,
                      "A request answers with the type its contract names.");
        return engine::Encode(answer);
      },
      request);
}

bool EngineBinding::Handle(const engine::GoToHistoryOffset& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->GoToOffset(request.offset);
}

bool EngineBinding::Handle(const engine::ReloadPage& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Reload(request.bypasses_cache);
}

bool EngineBinding::Handle(const engine::StopLoading& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->StopLoading();
}

bool EngineBinding::Handle(const engine::ZoomPage& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Zoom(request.factor);
}

bool EngineBinding::Handle(const engine::FindInPage& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Find(request.query, request.backwards, request.case_sensitive);
}

bool EngineBinding::Handle(const engine::CapturePage& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Capture(request.capture_id, request.area, request.width);
}

bool EngineBinding::Handle(const engine::ExportPage& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Export(request.export_id, request.format, request.width);
}

engine::InteractionState EngineBinding::Handle(const engine::SaveInteractionState& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return engine::InteractionState{.state = page ? page->SaveInteractionState() : std::nullopt};
}

bool EngineBinding::Handle(const engine::RestoreInteractionState& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Restore(request.state, request.expected_url);
}

bool EngineBinding::Handle(const engine::MovePageToWindow& request) {
  const std::string key = GuidText(request.page_id);
  EnginePage* page = Find(key);
  return page && page->phase() == EnginePage::Phase::kLive && shell_ &&
         shell_->MoveToWindow(key, GuidText(request.window_id));
}

bool EngineBinding::Handle(const engine::ShowPage& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Show();
}

bool EngineBinding::Handle(const engine::HidePage& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Hide();
}

engine::PageIconImage EngineBinding::Handle(const engine::PageIcon& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return engine::PageIconImage{.image = page ? page->icon() : std::nullopt};
}

// An engine page Settings shows is created like any other, in its window's
// Browser, and loads its address once it exists; the core never hears of it.
bool EngineBinding::Handle(const engine::OpenStandalonePage& request) {
  if (disposing_ || pages_.contains(GuidText(request.page_id))) {
    return false;
  }
  Create(engine::CreatePage{.page_id = request.page_id,
                            .profile_id = request.profile_id,
                            .is_private = false,
                            .window_id = request.window_id,
                            .restore_state = std::nullopt},
         /*standalone=*/true);
  Load(GuidText(request.page_id), request.url);
  return true;
}

bool EngineBinding::Handle(const engine::CloseStandalonePage& request) {
  const std::string key = GuidText(request.page_id);
  EnginePage* page = Find(key);
  if (!page || !page->standalone()) {
    return false;
  }
  page->Stop();
  pages_.erase(key);
  std::erase(due_, key);
  if (shell_) {
    shell_->DestroyContents(key);
  }
  return true;
}

// A page the platform comes to after the engine made it, or failed to,
// hears where it stands.
bool EngineBinding::Handle(const engine::WatchPage& request) {
  const std::string key = GuidText(request.page_id);
  if (EnginePage* page = Find(key)) {
    page->Watch();
    return true;
  }
  if (failed_.contains(key)) {
    Present(engine::PageViewUnavailable{.page_id = request.page_id});
    return true;
  }
  return false;
}

engine::PageMediaState EngineBinding::Handle(const engine::PageMedia& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return engine::PageMediaState{.activity = page ? page->MediaActivity() : engine::PageMediaActivity::kNone};
}

bool EngineBinding::Handle(const engine::EnterPictureInPicture& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->EnterPictureInPicture();
}

bool EngineBinding::Handle(const engine::ActivateMediaSession& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->ActivateMediaSession(request.document);
}

bool EngineBinding::Handle(const engine::PerformMediaAction& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->PerformMediaAction(request.document, request.action);
}

bool EngineBinding::Handle(const engine::MuteMediaSession& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->MuteMediaSession(request.document, request.muted);
}

bool EngineBinding::Handle(const engine::AnswerInfoBar& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->AnswerInfoBar(request.info_bar_id, request.answer);
}

bool EngineBinding::Handle(const engine::RefreshPageIcon& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->RefreshIcon();
}

bool EngineBinding::Handle(const engine::ShowBlockedPopups& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->ShowBlockedPopups();
}

bool EngineBinding::Handle(const engine::AddContentScript& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->AddContentScript(request.source, request.main_frame_only);
}

bool EngineBinding::Handle(const engine::EvaluateContentScript& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->EvaluateContentScript(request.evaluation_id, request.source, request.frame_id);
}

bool EngineBinding::Handle(const engine::RefreshStoreListing& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->FinishStoreRequest();
}

bool EngineBinding::Handle(const engine::OpenInspector& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->OpenInspector(request.panel);
}

bool EngineBinding::Handle(const engine::CloseInspector& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->CloseInspector();
}

bool EngineBinding::Handle(const engine::PageInspected& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->Inspected();
}

engine::InspectorLayout EngineBinding::Handle(const engine::LayoutInspector& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page ? page->LayoutInspector(request.width, request.height) : engine::InspectorLayout{};
}

// The toolbar's actions for a page's own tab, and a Space's pinned ones with
// no page open.
engine::ExtensionActionList EngineBinding::Handle(const engine::PageExtensions& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  if (!page || !page->web_contents() || disposing_) {
    return engine::ExtensionActionList{};
  }
  return Extensions().PageActions(page->web_contents(), page->profile());
}

engine::ExtensionActionList EngineBinding::Handle(const engine::PinnedExtensions& request) {
  const std::string profile_id = GuidText(request.profile_id);
  Profile* profile = disposing_ ? nullptr : Profiles().Find(profile_id);
  return profile ? Extensions().Pinned(profile, profile_id) : engine::ExtensionActionList{};
}

engine::InstalledExtensionList EngineBinding::Handle(const engine::InstalledExtensions& request) {
  const std::string profile_id = GuidText(request.profile_id);
  Profile* profile = disposing_ ? nullptr : Profiles().Find(profile_id);
  return profile ? Extensions().Installed(profile, profile_id) : engine::InstalledExtensionList{};
}

bool EngineBinding::Handle(const engine::ChangeExtension& request) {
  Profile* profile = disposing_ ? nullptr : Profiles().Find(GuidText(request.profile_id));
  return profile && Extensions().Change(profile, request.extension_id, request.change);
}

bool EngineBinding::Handle(const engine::HasSidePanel& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && EngineExtensions::SidePanelExtension(page->web_contents(), request.extension_id);
}

engine::CertificateChain EngineBinding::Handle(const engine::PageCertificates& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page ? page->CertificateChain() : engine::CertificateChain{};
}

bool EngineBinding::Handle(const engine::SetSitePermission& request) {
  EnginePage* page = Find(GuidText(request.page_id));
  return page && page->SetSitePermission(request.permission, request.allowed);
}

// Chromium enforces capture permissions itself: the SetSitePermission that
// withdraws a grant ends the capture it allowed.
bool EngineBinding::Handle(const engine::StopMediaCapture&) {
  return false;
}

// A Space's profile loads before anything opens in it, so its extensions
// can be listed; its extensions are followed from then on.
bool EngineBinding::Handle(const engine::PrepareProfile& request) {
  if (disposing_) {
    return false;
  }
  const std::string id = GuidText(request.profile_id);
  Profiles().Prepare(id, base::BindOnce(
                             [](base::WeakPtr<EngineBinding> binding, std::string id, engine::Guid preparation,
                                bool ready) {
                               if (!binding) {
                                 return;
                               }
                               if (ready) {
                                 binding->Extensions().For(binding->Profiles().Find(id), id);
                               }
                               binding->Present(engine::ProfilePrepared{.preparation_id = preparation, .ready = ready});
                             },
                             weak_factory_.GetWeakPtr(), id, request.preparation_id));
  return true;
}

// Its pages, Browsers and extensions go at once; its data after, loaded
// from disk when nothing had loaded it.
void EngineBinding::Erase(const engine::EraseProfileData& erasing) {
  const std::string id = GuidText(erasing.profile_id);
  const auto released = Profiles().BeginDeletion(id, erasing.ephemeral);
  if (!released) {
    Report(engine::DataErased{.erasure_id = erasing.erasure_id, .erased = false});
    return;
  }
  if (shell_) {
    shell_->ReleaseProfiles(*released);
  }
  for (const std::string& profile : *released) {
    Extensions().Forget(profile);
    Profiles().Release(profile);
  }
  Present(engine::ProfileReleased{.profile_id = erasing.profile_id});
  Profiles().Delete(id, erasing.ephemeral,
                    base::BindOnce(
                        [](base::WeakPtr<EngineBinding> binding, engine::Guid erasure, bool erased) {
                          if (binding) {
                            binding->Report(engine::DataErased{.erasure_id = erasure, .erased = erased});
                          }
                        },
                        weak_factory_.GetWeakPtr(), erasing.erasure_id));
}

// A private profile keeps a site's data only while it is open; a regular one
// on disk is loaded to clear it, and one never created has nothing to clear.
void EngineBinding::Erase(const engine::EraseSiteData& erasing) {
  const std::string id = GuidText(erasing.profile_id);
  auto done = base::BindOnce(
      [](base::WeakPtr<EngineBinding> binding, engine::Guid erasure, bool erased) {
        if (binding) {
          binding->Report(engine::DataErased{.erasure_id = erasure, .erased = erased});
        }
      },
      weak_factory_.GetWeakPtr(), erasing.erasure_id);
  const GURL site("https://" + erasing.host + "/");
  if (Profile* loaded = Profiles().Find(id)) {
    crest::ClearSiteData(loaded, site, std::move(done));
    return;
  }
  if (erasing.ephemeral || !Profiles().HasStore(id)) {
    std::move(done).Run(true);
    return;
  }
  Profiles().Load(id, /*is_private=*/false, id,
                  base::BindOnce(
                      [](GURL site, base::OnceCallback<void(bool)> done, Profile* profile) {
                        if (!profile) {
                          std::move(done).Run(false);
                          return;
                        }
                        crest::ClearSiteData(profile, site, std::move(done));
                      },
                      site, std::move(done)));
}

bool EngineBinding::Handle(const engine::AdoptOfferedPage& request) {
  return Adopt(GuidText(request.page_id), GuidText(request.adoption_id));
}

bool EngineBinding::Handle(const engine::RejectOfferedPage& request) {
  return shell_ && !disposing_ && shell_->RejectAdoption(GuidText(request.adoption_id));
}

// Reports and presentations.

void EngineBinding::Report(engine::EngineEvent event) {
  if (disposing_ || !report_) {
    return;
  }
  queue_.push_back(Outgoing{.to_core = true, .message = engine::Encode(event)});
  ScheduleFlush();
}

void EngineBinding::Present(engine::EnginePresentation presentation) {
  if (disposing_ || !present_) {
    return;
  }
  queue_.push_back(Outgoing{.to_core = false, .message = engine::Encode(presentation)});
  ScheduleFlush();
}

void EngineBinding::ReportStateSoon(const std::string& key) {
  if (disposing_) {
    return;
  }
  if (std::find(due_.begin(), due_.end(), key) == due_.end()) {
    due_.push_back(key);
  }
  ScheduleFlush();
}

void EngineBinding::ScheduleFlush() {
  if (flush_posted_ || flushing_) {
    return;
  }
  flush_posted_ = true;
  base::SequencedTaskRunner::GetCurrentDefault()->PostTask(
      FROM_HERE, base::BindOnce(&EngineBinding::Flush, weak_factory_.GetWeakPtr()));
}

// Sends what is queued, oldest first, then the snapshots due this turn. A
// report can make the core deliver a command, which can queue more; those go
// out in the same pass.
void EngineBinding::Flush() {
  flush_posted_ = false;
  flushing_ = true;
  while (!disposing_ && (!queue_.empty() || !due_.empty())) {
    if (queue_.empty()) {
      std::vector<std::string> due = std::move(due_);
      due_.clear();
      for (const std::string& key : due) {
        if (EnginePage* page = Find(key)) {
          page->ReportState();
        }
      }
      continue;
    }
    Outgoing next = std::move(queue_.front());
    queue_.pop_front();
    if (!next.to_core) {
      if (present_) {
        present_(ui_, next.message.data(), next.message.size());
      }
      continue;
    }
    const crest_status_t status = report_(app_, engine_, next.message.data(), next.message.size());
    // A report is never refused; any other answer is a build bug.
    DCHECK(status == CREST_OK || status == CREST_INVALID_HANDLE) << "The core refused an engine report: " << status;
  }
  flushing_ = false;
}

EnginePage* EngineBinding::Find(const std::string& key) {
  auto found = pages_.find(key);
  return found == pages_.end() ? nullptr : found->second.get();
}

// The engine's own hooks, for the pages that follow the WebContents they name.

void ReportContentFullscreen(content::WebContents* contents, bool active) {
  if (EnginePage* page = EngineBinding::Get().PageFor(contents)) {
    page->FullscreenChanged(active);
  }
}

void UpdateTargetURL(content::WebContents* contents, const GURL& url) {
  if (EnginePage* page = EngineBinding::Get().PageFor(contents)) {
    page->HoverChanged(url);
  }
}

void UpdateSiteIndicators(content::WebContents* contents) {
  if (EnginePage* page = EngineBinding::Get().PageFor(contents)) {
    page->SiteIndicatorsChanged();
  }
}

// Extension side panels are cards beside Crest's pages, so this build never
// creates Chrome's Views side-panel UI: `chrome.sidePanel.open()` and
// `close()` are asked of the page that shows `contents`. False leaves a
// WebContents no Crest page shows to the engine.
bool OpenExtensionSidePanel(content::WebContents* contents, const std::string& extension_id) {
  EnginePage* page = EngineBinding::Get().PageFor(contents);
  if (!page) {
    return false;
  }
  EngineBinding::Get().RequestSidePanel(page->key(), extension_id, engine::SidePanelRequest::kOpen);
  return true;
}

bool CloseExtensionSidePanel(content::WebContents* contents, const std::string& extension_id) {
  EnginePage* page = EngineBinding::Get().PageFor(contents);
  if (!page) {
    return false;
  }
  EngineBinding::Get().RequestSidePanel(page->key(), extension_id, engine::SidePanelRequest::kClose);
  return true;
}

// Crest shows script dialogs for its pages with the same presenter WebKit's
// pages use. Other engine pages keep the engine's dialog manager.
content::JavaScriptDialogManager* JavaScriptDialogManagerFor(content::WebContents* contents) {
  return EngineBinding::Get().PageFor(contents) ? &EngineBinding::Get().Prompts() : nullptr;
}

// Basic and Digest challenges go through Crest's per-Space credentials. False
// leaves a WebContents Crest does not show, a proxy's challenge or another
// scheme to the engine.
bool PresentHTTPAuthentication(content::WebContents* contents,
                               const net::AuthChallengeInfo& challenge,
                               std::function<void(bool, const std::u16string&, const std::u16string&)> reply) {
  EnginePage* page = EngineBinding::Get().PageFor(contents);
  if (!page || challenge.is_proxy || (challenge.scheme != "basic" && challenge.scheme != "digest")) {
    return false;
  }
  const int previous_failures = page->AuthenticationAttempt(challenge.challenger.GetURL().spec() + "\n" +
                                                            challenge.scheme + "\n" + challenge.realm);
  EngineBinding::Get().Prompts().Authenticate(page->id(), challenge, previous_failures, std::move(reply));
  return true;
}

// Downloads in Crest's profiles are Crest's to show; the rest stay the engine's.
bool OwnsDownload(download::DownloadItem* item) {
  auto& binding = EngineBinding::Get();
  return !binding.disposing() && binding.Downloads().Owns(item);
}

void PublishDownload(download::DownloadItem* item) {
  auto& binding = EngineBinding::Get();
  if (!binding.disposing()) {
    binding.Downloads().Changed(item);
  }
}

void ChooseDownloadDestination(download::DownloadItem* item,
                               const base::FilePath& suggested_path,
                               DownloadConfirmationReason reason,
                               DownloadTargetDeterminerDelegate::ConfirmationCallback callback) {
  auto& binding = EngineBinding::Get();
  if (binding.disposing()) {
    std::move(callback).Run(DownloadConfirmationResult::CANCELED, ui::SelectedFileInfo());
    return;
  }
  binding.Downloads().ChooseDestination(item, suggested_path, reason, std::move(callback));
}

bool CanDockDevTools(content::WebContents* inspected) {
  return EngineBinding::Get().PageFor(inspected) != nullptr;
}

bool UpdateDockedDevTools(content::WebContents* inspected) {
  EnginePage* page = EngineBinding::Get().PageFor(inspected);
  if (!page) {
    return false;
  }
  page->InspectorChanged();
  return true;
}

void OnDevToolsClosing(content::WebContents* inspected) {
  if (EnginePage* page = EngineBinding::Get().PageFor(inspected)) {
    page->InspectorClosing();
  }
}

bool AnswerBeforeUnload(content::WebContents* contents, bool proceed) {
  EnginePage* page = EngineBinding::Get().PageFor(contents);
  return page && page->AnswerBeforeUnload(proceed);
}

}  // namespace crest
