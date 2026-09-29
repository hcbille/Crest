#ifndef CHROME_BROWSER_UI_CREST_CREST_ENGINE_SCREEN_SHARING_H_
#define CHROME_BROWSER_UI_CREST_CREST_ENGINE_SCREEN_SHARING_H_

#include <memory>
#include <optional>
#include <vector>

#include "base/memory/weak_ptr.h"
#include "chrome/browser/media/webrtc/desktop_media_picker.h"
#include "chrome/browser/ui/crest/crest_engine_contract.h"
#include "content/public/browser/desktop_media_id.h"
#include "third_party/webrtc/modules/desktop_capture/desktop_capturer.h"
#include "url/gurl.h"

namespace content {
struct MediaStreamRequest;
}

namespace crest {

// A page's getDisplayMedia() in Crest. The core decides first whether the
// page's site may ask, from its Space's choices; then the system's own sharing
// picker asks the person which window or display to share. That choice is the
// consent, and it needs no Screen Recording access, so nothing lists or
// captures the screen before the person picks, and nothing asks the system for
// access. The person's choice reaches the page as the picker's session, which
// the engine captures with the filter the system handed it.
class ScreenSharingPicker final : public DesktopMediaPicker {
 public:
  explicit ScreenSharingPicker(const content::MediaStreamRequest& request);
  ScreenSharingPicker(const ScreenSharingPicker&) = delete;
  ScreenSharingPicker& operator=(const ScreenSharingPicker&) = delete;
  // A request that ends before the person chose takes back what it asked:
  // the core's question, or the system's picker.
  ~ScreenSharingPicker() override;

  // DesktopMediaPicker:
  void Show(const Params& params,
            std::vector<std::unique_ptr<DesktopMediaList>> source_lists,
            DoneCallback done_callback) override;

 private:
  void Answered(bool proceeds);
  void Opened(content::DesktopMediaID::Id session);
  void Chosen(webrtc::DesktopCapturer::Source source);
  void Finish(DoneCallbackArgumentType result);

  // The document that asked.
  const GURL origin_;
  DoneCallback done_;
  // The core's question while it waits.
  std::optional<engine::Guid> question_;
  // The system picker's session once it opened.
  std::optional<content::DesktopMediaID::Id> session_;
  bool chosen_ = false;
  base::WeakPtrFactory<ScreenSharingPicker> weak_factory_{this};
};

}  // namespace crest

#endif  // CHROME_BROWSER_UI_CREST_CREST_ENGINE_SCREEN_SHARING_H_
