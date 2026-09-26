#ifndef CHROME_BROWSER_UI_CREST_CREST_ENGINE_PROMPTS_H_
#define CHROME_BROWSER_UI_CREST_CREST_ENGINE_PROMPTS_H_

#include <functional>
#include <map>
#include <memory>
#include <string>

#include "base/functional/callback.h"
#include "base/memory/raw_ptr.h"
#include "base/memory/weak_ptr.h"
#include "chrome/browser/ui/crest/crest_engine_contract.h"
#include "components/permissions/permission_prompt.h"
#include "content/public/browser/javascript_dialog_manager.h"

class GURL;
class Profile;

namespace content {
class WebContents;
}

namespace net {
class AuthChallengeInfo;
}

namespace crest {

// What an engine page asks the person, presented for the platform to show and
// answered by the platform's request. TRANSITIONAL until page dialogs and
// permission prompts move to the core (WP C (e), (f)).
class EnginePrompts final : public content::JavaScriptDialogManager {
 public:
  using Present = base::RepeatingCallback<void(engine::EnginePresentation)>;
  using AuthenticationReply = std::function<void(bool, const std::u16string&, const std::u16string&)>;

  explicit EnginePrompts(Present present);
  EnginePrompts(const EnginePrompts&) = delete;
  EnginePrompts& operator=(const EnginePrompts&) = delete;
  ~EnginePrompts() override;

  // A script dialog in `contents`, which the page `page` shows.
  bool Answer(const engine::AnswerJavaScriptDialog& answer);

  // An HTTP challenge for `page`'s load, the `previous_failures`th for the
  // same server and realm.
  void Authenticate(const engine::Guid& page,
                    const net::AuthChallengeInfo& challenge,
                    int previous_failures,
                    AuthenticationReply reply);
  bool Answer(const engine::AnswerAuthentication& answer);

  // A permission request Crest's record covers, or nullptr for any other.
  std::unique_ptr<permissions::PermissionPrompt> Prompt(const engine::Guid& page,
                                                         permissions::PermissionPrompt::Delegate* delegate);
  bool Answer(const engine::AnswerPermission& answer);

  // The page closed: what it asked goes unanswered.
  void Forget(const engine::Guid& page);

  // content::JavaScriptDialogManager:
  void RunJavaScriptDialog(content::WebContents* contents,
                           content::RenderFrameHost* frame,
                           content::JavaScriptDialogType type,
                           const std::u16string& message,
                           const std::u16string& default_text,
                           DialogClosedCallback callback,
                           bool* did_suppress_message) override;
  void RunBeforeUnloadDialog(content::WebContents* contents,
                             content::RenderFrameHost* frame,
                             bool is_reload,
                             DialogClosedCallback callback) override;
  bool HandleJavaScriptDialog(content::WebContents* contents,
                              bool accept,
                              const std::u16string* prompt_override) override;
  void CancelDialogs(content::WebContents* contents, bool reset_state) override;

 private:
  class PermissionPrompt;
  struct Dialog {
    engine::Guid page;
    engine::Guid id;
    DialogClosedCallback callback;
  };
  struct Challenge {
    engine::Guid page;
    AuthenticationReply reply;
  };

  void Open(content::WebContents* contents,
            content::RenderFrameHost* frame,
            engine::JavaScriptDialogKind kind,
            const std::u16string& message,
            const std::u16string& default_text,
            DialogClosedCallback callback);
  void Close(content::WebContents* contents, const engine::Guid& id, bool accepted, const std::u16string& input);

  const Present present_;
  std::map<content::WebContents*, Dialog> dialogs_;
  std::map<engine::Guid, Challenge> challenges_;
  std::map<engine::Guid, base::WeakPtr<PermissionPrompt>> permissions_;
};

// A fresh identity for something the binding asks the platform.
engine::Guid RandomGuid();

// Removes one site's cookies, storage and cache from `profile`, then answers.
void ClearSiteData(Profile* profile, const GURL& url, base::OnceCallback<void(bool)> done);

}  // namespace crest

#endif  // CHROME_BROWSER_UI_CREST_CREST_ENGINE_PROMPTS_H_
