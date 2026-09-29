#include "chrome/browser/ui/crest/crest_engine_screen_sharing.h"

#include <CoreGraphics/CoreGraphics.h>

#include <utility>

#include "base/feature_list.h"
#include "base/functional/bind.h"
#include "base/task/bind_post_task.h"
#include "base/task/sequenced_task_runner.h"
#include "base/types/expected.h"
#include "chrome/browser/ui/crest/crest_chrome_hooks.h"
#include "chrome/browser/ui/crest/crest_engine_binding.h"
#include "chrome/browser/ui/crest/crest_engine_page.h"
#include "chrome/browser/ui/crest/crest_engine_prompts.h"
#include "content/public/browser/browser_task_traits.h"
#include "content/public/browser/browser_thread.h"
#include "content/public/browser/desktop_capture.h"
#include "content/public/browser/media_stream_request.h"
#include "content/public/browser/web_contents.h"
#include "media/base/media_switches.h"
#include "third_party/blink/public/mojom/mediastream/media_stream.mojom.h"
#include "third_party/webrtc/modules/desktop_capture/desktop_capture_types.h"

namespace crest {

namespace {

using blink::mojom::MediaStreamRequestResult;
using content::DesktopMediaID;

// A refusal the page hears as NotAllowedError.
DesktopMediaPicker::DoneCallbackArgumentType Refusal(MediaStreamRequestResult result) {
  return base::unexpected(result);
}

// Closes the system picker's session `session` when no capture holds it.
void CloseSession(DesktopMediaID::Id session) {
  content::GetIOThreadTaskRunner({})->PostTask(
      FROM_HERE, base::BindOnce(&content::desktop_capture::CloseNativeScreenCapturePicker,
                                DesktopMediaID(DesktopMediaID::TYPE_NONE, session)));
}

}  // namespace

ScreenSharingPicker::ScreenSharingPicker(const content::MediaStreamRequest& request)
    : origin_(request.security_origin) {}

ScreenSharingPicker::~ScreenSharingPicker() {
  if (question_ && !EngineBinding::Get().disposing()) {
    EngineBinding::Get().Prompts().WithdrawShare(*question_);
  }
  if (session_ && !chosen_) {
    CloseSession(*session_);
  }
}

void ScreenSharingPicker::Show(const Params& params,
                               std::vector<std::unique_ptr<DesktopMediaList>> source_lists,
                               DoneCallback done_callback) {
  DCHECK_CURRENTLY_ON(content::BrowserThread::UI);
  done_ = std::move(done_callback);
  // Only a page Crest shows has a Space whose choices answer it. The refusal
  // is posted, since the caller still holds this picker.
  EnginePage* page = params.web_contents ? EngineBinding::Get().PageFor(params.web_contents) : nullptr;
  if (!page) {
    base::SequencedTaskRunner::GetCurrentDefault()->PostTask(
        FROM_HERE, base::BindOnce(&ScreenSharingPicker::Finish, weak_factory_.GetWeakPtr(),
                                  Refusal(MediaStreamRequestResult::PERMISSION_DENIED)));
    return;
  }
  question_ = EngineBinding::Get().Prompts().AskToShareScreen(
      page->id(), origin_, params.web_contents->GetLastCommittedURL(),
      base::BindOnce(&ScreenSharingPicker::Answered, weak_factory_.GetWeakPtr()));
}

// The core answered: a Space that blocks the site refuses it, and otherwise
// the system's picker asks the person. The picker offers a window or a
// display; what it shows and the capture it grants are the system's own.
void ScreenSharingPicker::Answered(bool proceeds) {
  question_.reset();
  if (!proceeds) {
    Finish(Refusal(MediaStreamRequestResult::PERMISSION_DENIED));
    return;
  }
  auto ui = content::GetUIThreadTaskRunner({});
  content::GetIOThreadTaskRunner({})->PostTask(
      FROM_HERE,
      base::BindOnce(
          &content::desktop_capture::OpenNativeScreenCapturePicker, DesktopMediaID::TYPE_NONE,
          base::BindPostTask(ui, base::BindOnce(&ScreenSharingPicker::Opened, weak_factory_.GetWeakPtr())),
          base::BindPostTask(ui, base::BindOnce(&ScreenSharingPicker::Chosen, weak_factory_.GetWeakPtr())),
          base::BindPostTask(ui, base::BindOnce(&ScreenSharingPicker::Finish, weak_factory_.GetWeakPtr(),
                                                Refusal(MediaStreamRequestResult::PERMISSION_DENIED_BY_USER))),
          base::BindPostTask(ui, base::BindOnce(&ScreenSharingPicker::Finish, weak_factory_.GetWeakPtr(),
                                                Refusal(MediaStreamRequestResult::PERMISSION_DENIED_BY_SYSTEM)))));
}

void ScreenSharingPicker::Opened(DesktopMediaID::Id session) {
  session_ = session;
}

// The person chose. A display carries its ID and a window none; either is the
// picker's session, which the engine captures with the system's own filter.
// Audio is not shared: the system's picker offers none.
void ScreenSharingPicker::Chosen(webrtc::DesktopCapturer::Source source) {
  chosen_ = true;
  DesktopMediaID chosen(
      source.display_id != webrtc::kInvalidDisplayId ? DesktopMediaID::TYPE_SCREEN : DesktopMediaID::TYPE_WINDOW,
      source.id);
  chosen.id_type = DesktopMediaID::IdType::kNativePickerSession;
  Finish(chosen);
}

void ScreenSharingPicker::Finish(DoneCallbackArgumentType result) {
  if (done_) {
    std::move(done_).Run(std::move(result));
  }
}

bool SharesScreenThroughSystem(const content::MediaStreamRequest& request) {
  return IsEnabled() && request.video_type == blink::mojom::MediaStreamType::DISPLAY_VIDEO_CAPTURE &&
         base::FeatureList::IsEnabled(media::kUseSCContentSharingPicker);
}

std::unique_ptr<DesktopMediaPicker> CreateScreenSharingPicker(const content::MediaStreamRequest& request) {
  return std::make_unique<ScreenSharingPicker>(request);
}

// Screen Recording access, for capture that still needs it: a whole display or
// another app's window chosen some other way than through the system's picker,
// as an extension's `chrome.desktopCapture` can. macOS applies a grant only
// after Crest reopens, so the engine asks the system once per launch, which
// raises at most one system prompt, and after a refusal answers from memory
// without asking again. The person hears once where to allow it.
bool AllowsScreenCapture(content::WebContents* contents, const content::DesktopMediaID& source) {
  DCHECK_CURRENTLY_ON(content::BrowserThread::UI);
  const bool needs_access =
      source.id_type != DesktopMediaID::IdType::kNativePickerSession &&
      (source.type == DesktopMediaID::TYPE_SCREEN ||
       (source.type == DesktopMediaID::TYPE_WINDOW && source.window_id == DesktopMediaID::kNullId));
  if (!needs_access) {
    return true;
  }
  static bool asked = false;
  static bool missing = false;
  if (missing) {
    return false;
  }
  if (CGPreflightScreenCaptureAccess()) {
    return true;
  }
  if (!asked) {
    asked = true;
    if (CGRequestScreenCaptureAccess()) {
      return true;
    }
  }
  missing = true;
  if (EnginePage* page = contents ? EngineBinding::Get().PageFor(contents) : nullptr) {
    EngineBinding::Get().Present(engine::ScreenCaptureAccessMissing{.page_id = page->id()});
  }
  return false;
}

}  // namespace crest
