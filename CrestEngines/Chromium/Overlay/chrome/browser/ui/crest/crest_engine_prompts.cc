#include "chrome/browser/ui/crest/crest_engine_prompts.h"

#include <optional>
#include <utility>
#include <variant>
#include <vector>

#include "base/strings/utf_string_conversions.h"
#include "base/uuid.h"
#include "chrome/browser/browsing_data/chrome_browsing_data_remover_constants.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/browser/ui/crest/crest_engine_binding.h"
#include "chrome/browser/ui/crest/crest_engine_page.h"
#include "components/permissions/permission_request.h"
#include "components/permissions/request_type.h"
#include "content/public/browser/browsing_data_filter_builder.h"
#include "content/public/browser/browsing_data_remover.h"
#include "content/public/browser/render_frame_host.h"
#include "content/public/browser/web_contents.h"
#include "net/base/auth.h"
#include "net/base/registry_controlled_domains/registry_controlled_domain.h"
#include "url/gurl.h"

namespace crest {

namespace {

// The Crest permission a batch of engine requests amounts to, or nothing when
// any of them is one Crest's record does not cover.
std::optional<engine::SitePermission> PermissionFor(permissions::PermissionPrompt::Delegate* delegate) {
  bool camera = false;
  bool microphone = false;
  std::optional<engine::SitePermission> single;
  bool several = false;
  for (const auto& request : delegate->Requests()) {
    switch (request->request_type()) {
      case permissions::RequestType::kCameraStream:
        camera = true;
        break;
      case permissions::RequestType::kMicStream:
        microphone = true;
        break;
      case permissions::RequestType::kGeolocation:
        several = several || single.has_value();
        single = engine::SitePermission::kLocation;
        break;
      case permissions::RequestType::kNotifications:
        several = several || single.has_value();
        single = engine::SitePermission::kNotifications;
        break;
      default:
        return std::nullopt;
    }
  }
  if (camera || microphone) {
    if (single) {
      return std::nullopt;
    }
    return camera && microphone ? engine::SitePermission::kCameraAndMicrophone
           : camera             ? engine::SitePermission::kCamera
                                : engine::SitePermission::kMicrophone;
  }
  return several ? std::nullopt : single;
}

// Removes a site's data, then answers; it owns itself until the remover
// reports back.
class SiteDataClearance final : public content::BrowsingDataRemover::Observer {
 public:
  SiteDataClearance(content::BrowsingDataRemover* remover, base::OnceCallback<void(bool)> done)
      : remover_(remover), done_(std::move(done)) {
    remover_->AddObserver(this);
  }

  void OnBrowsingDataRemoverDone(uint64_t failures) override {
    remover_->RemoveObserver(this);
    std::move(done_).Run(failures == 0);
    delete this;
  }

 private:
  const raw_ptr<content::BrowsingDataRemover> remover_;
  base::OnceCallback<void(bool)> done_;
};

}  // namespace

engine::Guid RandomGuid() {
  return *ParseGuid(base::Uuid::GenerateRandomV4().AsLowercaseString());
}

void ClearSiteData(Profile* profile, const GURL& url, base::OnceCallback<void(bool)> done) {
  std::string domain = net::registry_controlled_domains::GetDomainAndRegistry(
      url, net::registry_controlled_domains::INCLUDE_PRIVATE_REGISTRIES);
  if (domain.empty()) {
    domain = url.host();
  }
  if (domain.empty()) {
    std::move(done).Run(false);
    return;
  }
  auto filter = content::BrowsingDataFilterBuilder::Create(content::BrowsingDataFilterBuilder::Mode::kDelete);
  filter->AddRegisterableDomain(domain);
  auto* remover = profile->GetBrowsingDataRemover();
  auto* clearance = new SiteDataClearance(remover, std::move(done));
  remover->RemoveWithFilterAndReply(
      base::Time(), base::Time::Max(),
      chrome_browsing_data_remover::DATA_TYPE_SITE_DATA | content::BrowsingDataRemover::DATA_TYPE_CACHE,
      content::BrowsingDataRemover::ORIGIN_TYPE_UNPROTECTED_WEB, std::move(filter), clearance);
}

// A request Crest's permission record covers, asked through the page so the
// decision is recorded per Space and listed in Privacy.
class EnginePrompts::PermissionPrompt final : public permissions::PermissionPrompt {
 public:
  explicit PermissionPrompt(Delegate* delegate) : delegate_(delegate->GetWeakPtr()) {}

  base::WeakPtr<PermissionPrompt> GetWeakPtr() { return weak_factory_.GetWeakPtr(); }

  void Answer(engine::PermissionAnswer answer) {
    if (!delegate_) {
      return;
    }
    switch (answer) {
      case engine::PermissionAnswer::kAllow:
        delegate_->Accept(std::monostate());
        break;
      case engine::PermissionAnswer::kAllowOnce:
        delegate_->AcceptThisTime(std::monostate());
        break;
      case engine::PermissionAnswer::kBlock:
        delegate_->Deny(std::monostate());
        break;
      case engine::PermissionAnswer::kDismiss:
        delegate_->Dismiss(std::monostate());
        break;
    }
  }

  // permissions::PermissionPrompt:
  bool UpdateAnchor() override { return true; }
  TabSwitchingBehavior GetTabSwitchingBehavior() override { return kKeepPromptAlive; }
  permissions::PermissionPromptDisposition GetPromptDisposition() const override {
    return permissions::PermissionPromptDisposition::ANCHORED_BUBBLE;
  }
  bool IsAskPrompt() const override { return true; }
  std::optional<gfx::Rect> GetViewBoundsInScreen() const override { return std::nullopt; }
  bool ShouldFinalizeRequestAfterDecided() const override { return true; }
  std::vector<permissions::ElementAnchoredBubbleVariant> GetPromptVariants() const override { return {}; }
  std::optional<permissions::feature_params::PermissionElementPromptPosition> GetPromptPosition() const override {
    return std::nullopt;
  }

 private:
  base::WeakPtr<Delegate> delegate_;
  base::WeakPtrFactory<PermissionPrompt> weak_factory_{this};
};

EnginePrompts::EnginePrompts(Present present) : present_(std::move(present)) {}

EnginePrompts::~EnginePrompts() = default;

// Script dialogs.

void EnginePrompts::RunJavaScriptDialog(content::WebContents* contents,
                                        content::RenderFrameHost* frame,
                                        content::JavaScriptDialogType type,
                                        const std::u16string& message,
                                        const std::u16string& default_text,
                                        DialogClosedCallback callback,
                                        bool* did_suppress_message) {
  *did_suppress_message = false;
  const auto kind = type == content::JAVASCRIPT_DIALOG_TYPE_ALERT     ? engine::JavaScriptDialogKind::kAlert
                    : type == content::JAVASCRIPT_DIALOG_TYPE_CONFIRM ? engine::JavaScriptDialogKind::kConfirm
                                                                      : engine::JavaScriptDialogKind::kPrompt;
  Open(contents, frame, kind, message, default_text, std::move(callback));
}

void EnginePrompts::RunBeforeUnloadDialog(content::WebContents* contents,
                                          content::RenderFrameHost* frame,
                                          bool is_reload,
                                          DialogClosedCallback callback) {
  Open(contents, frame, engine::JavaScriptDialogKind::kBeforeUnload, u"", u"", std::move(callback));
}

bool EnginePrompts::HandleJavaScriptDialog(content::WebContents* contents,
                                           bool accept,
                                           const std::u16string* prompt_override) {
  auto found = dialogs_.find(contents);
  if (found == dialogs_.end()) {
    return false;
  }
  Close(contents, found->second.id, accept, prompt_override ? *prompt_override : std::u16string());
  return true;
}

void EnginePrompts::CancelDialogs(content::WebContents* contents, bool reset_state) {
  if (auto found = dialogs_.find(contents); found != dialogs_.end()) {
    Close(contents, found->second.id, false, u"");
  }
}

// A page shows one dialog at a time; a new one cancels the one before.
void EnginePrompts::Open(content::WebContents* contents,
                         content::RenderFrameHost* frame,
                         engine::JavaScriptDialogKind kind,
                         const std::u16string& message,
                         const std::u16string& default_text,
                         DialogClosedCallback callback) {
  CancelDialogs(contents, false);
  EnginePage* page = EngineBinding::Get().PageFor(contents);
  if (!page) {
    std::move(callback).Run(false, u"");
    return;
  }
  const engine::Guid id = RandomGuid();
  dialogs_[contents] = Dialog{.page = page->id(), .id = id, .callback = std::move(callback)};
  const GURL source = frame ? frame->GetLastCommittedURL() : contents->GetLastCommittedURL();
  present_.Run(engine::JavaScriptDialogRequested{.page_id = page->id(),
                                                 .dialog_id = id,
                                                 .kind = kind,
                                                 .message = base::UTF16ToUTF8(message),
                                                 .default_text = base::UTF16ToUTF8(default_text),
                                                 .source_url = PresentedURL(source)});
}

void EnginePrompts::Close(content::WebContents* contents,
                          const engine::Guid& id,
                          bool accepted,
                          const std::u16string& input) {
  auto found = dialogs_.find(contents);
  if (found == dialogs_.end() || found->second.id != id) {
    return;
  }
  auto callback = std::move(found->second.callback);
  dialogs_.erase(found);
  std::move(callback).Run(accepted, input);
}

bool EnginePrompts::Answer(const engine::AnswerJavaScriptDialog& answer) {
  for (auto& [contents, dialog] : dialogs_) {
    if (dialog.id == answer.dialog_id && dialog.page == answer.page_id) {
      Close(contents, answer.dialog_id, answer.accepted, base::UTF8ToUTF16(answer.input.value_or("")));
      return true;
    }
  }
  return false;
}

// HTTP authentication.

void EnginePrompts::Authenticate(const engine::Guid& page,
                                 const net::AuthChallengeInfo& challenge,
                                 int previous_failures,
                                 AuthenticationReply reply) {
  const engine::Guid id = RandomGuid();
  challenges_[id] = Challenge{.page = page, .reply = std::move(reply)};
  const GURL url = challenge.challenger.GetURL();
  present_.Run(engine::AuthenticationRequested{
      .page_id = page,
      .challenge_id = id,
      .url = url.spec(),
      .host = challenge.challenger.host(),
      .port = challenge.challenger.port(),
      .realm = challenge.realm.empty() ? std::nullopt : std::optional<std::string>(challenge.realm),
      .scheme = challenge.scheme == "digest" ? engine::AuthenticationScheme::kDigest
                                             : engine::AuthenticationScheme::kBasic,
      .is_proxy = challenge.is_proxy,
      .previous_failures = previous_failures});
}

bool EnginePrompts::Answer(const engine::AnswerAuthentication& answer) {
  auto found = challenges_.find(answer.challenge_id);
  if (found == challenges_.end() || found->second.page != answer.page_id) {
    return false;
  }
  auto reply = std::move(found->second.reply);
  challenges_.erase(found);
  if (answer.credential) {
    reply(true, base::UTF8ToUTF16(answer.credential->username), base::UTF8ToUTF16(answer.credential->password));
  } else {
    reply(false, u"", u"");
  }
  return true;
}

// Permission requests.

std::unique_ptr<permissions::PermissionPrompt> EnginePrompts::Prompt(
    const engine::Guid& page,
    permissions::PermissionPrompt::Delegate* delegate) {
  const auto permission = PermissionFor(delegate);
  if (!permission) {
    return nullptr;
  }
  auto prompt = std::make_unique<PermissionPrompt>(delegate);
  const engine::Guid id = RandomGuid();
  std::erase_if(permissions_, [](const auto& entry) { return !entry.second; });
  permissions_[id] = prompt->GetWeakPtr();
  present_.Run(engine::PermissionRequested{.page_id = page,
                                           .request_id = id,
                                           .permission = *permission,
                                           .origin = delegate->GetRequestingOrigin().spec(),
                                           .top_level_origin = delegate->GetEmbeddingOrigin().spec()});
  return prompt;
}

bool EnginePrompts::Answer(const engine::AnswerPermission& answer) {
  auto found = permissions_.find(answer.request_id);
  if (found == permissions_.end()) {
    return false;
  }
  base::WeakPtr<PermissionPrompt> prompt = found->second;
  permissions_.erase(found);
  if (!prompt) {
    return false;
  }
  prompt->Answer(answer.answer);
  return true;
}

void EnginePrompts::Forget(const engine::Guid& page) {
  std::erase_if(challenges_, [&](const auto& entry) { return entry.second.page == page; });
}

}  // namespace crest
