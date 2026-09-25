#include "chrome/browser/ui/crest/crest_engine_media.h"

#include <utility>

#include "base/strings/utf_string_conversions.h"
#include "chrome/browser/media/webrtc/media_capture_devices_dispatcher.h"
#include "chrome/browser/media/webrtc/media_stream_capture_indicator.h"
#include "chrome/browser/ui/crest/crest_engine_page.h"
#include "content/public/browser/media_session.h"
#include "content/public/browser/web_contents.h"
#include "services/media_session/public/cpp/media_metadata.h"

namespace crest {

namespace {

// The longest document identity Crest issues.
constexpr size_t kDocumentLength = 128;

std::optional<std::string> Text(const std::u16string& value) {
  return value.empty() ? std::nullopt : std::optional<std::string>(base::UTF16ToUTF8(value));
}

}  // namespace

PageMedia::PageMedia(content::WebContents* contents, const engine::Guid& page, Present present,
                     base::RepeatingClosure changed)
    : contents_(contents), page_(page), present_(std::move(present)), changed_(std::move(changed)) {
  if (auto* session = content::MediaSession::Get(contents)) {
    session->AddObserver(receiver_.BindNewPipeAndPassRemote());
  }
}

PageMedia::~PageMedia() = default;

engine::PageMediaActivity PageMedia::Activity() const {
  using engine::PageMediaActivity;
  PageMediaActivity activity = PageMediaActivity::kNone;
  if (played_before_hidden_ || !playing_videos_.empty() || last_playing_ || contents_->IsCurrentlyAudible() ||
      contents_->GetCurrentlyPlayingVideoCount() > 0) {
    activity = activity | PageMediaActivity::kPlaying;
  }
  auto indicator = MediaCaptureDevicesDispatcher::GetInstance()->GetMediaStreamCaptureIndicator();
  if (contents_->IsBeingCaptured() || indicator->IsCapturingUserMedia(contents_) ||
      indicator->IsCapturingTab(contents_) || indicator->IsCapturingWindow(contents_) ||
      indicator->IsCapturingDisplay(contents_)) {
    activity = activity | PageMediaActivity::kCapturing;
  }
  if (contents_->HasPictureInPictureVideo() || contents_->HasPictureInPictureDocument()) {
    activity = activity | PageMediaActivity::kPictureInPicture;
  }
  return activity;
}

void PageMedia::PlayerStarted(const content::MediaPlayerId& id, bool has_video) {
  if (has_video) {
    playing_videos_.insert(id);
  }
}

void PageMedia::PlayerStopped(const content::MediaPlayerId& id) {
  playing_videos_.erase(id);
}

void PageMedia::AudioChanged() {
  Publish();
}

void PageMedia::DocumentChanged() {
  document_.clear();
  seen_active_ = false;
  last_playing_ = false;
  playing_videos_.clear();
  played_before_hidden_ = false;
}

void PageMedia::VisibilityChanged(bool visible) {
  played_before_hidden_ = !visible && !playing_videos_.empty();
}

// The browser's Media Session chooses the active video player and asks its
// renderer to enter Picture in Picture; no page gesture is synthesized.
bool PageMedia::EnterPictureInPicture() {
  if ((!played_before_hidden_ && playing_videos_.empty() && !last_playing_ &&
       contents_->GetCurrentlyPlayingVideoCount() == 0) ||
      contents_->HasPictureInPictureVideo() || contents_->HasPictureInPictureDocument()) {
    return false;
  }
  auto* session = content::MediaSession::GetIfExists(contents_);
  if (!session) {
    return false;
  }
  session->EnterPictureInPicture();
  return true;
}

bool PageMedia::Activate(const std::string& document) {
  if (document.empty() || document.size() > kDocumentLength) {
    return false;
  }
  document_ = document;
  Publish();
  return true;
}

bool PageMedia::Perform(const std::string& document, engine::MediaSessionAction action) {
  if (document.empty() || document != document_) {
    return false;
  }
  auto* session = content::MediaSession::Get(contents_);
  if (!session) {
    return false;
  }
  using SuspendType = media_session::mojom::MediaSession::SuspendType;
  switch (action) {
    case engine::MediaSessionAction::kPlay:
      session->Resume(SuspendType::kUI);
      break;
    case engine::MediaSessionAction::kPause:
      session->Suspend(SuspendType::kUI);
      break;
    case engine::MediaSessionAction::kPreviousTrack:
      session->PreviousTrack();
      break;
    case engine::MediaSessionAction::kNextTrack:
      session->NextTrack();
      break;
  }
  return true;
}

bool PageMedia::Mute(const std::string& document, bool muted) {
  if (document.empty() || document != document_) {
    return false;
  }
  contents_->SetAudioMuted(muted);
  return true;
}

void PageMedia::MediaSessionInfoChanged(media_session::mojom::MediaSessionInfoPtr info) {
  info_ = std::move(info);
  Publish();
}

void PageMedia::MediaSessionMetadataChanged(const std::optional<media_session::MediaMetadata>& metadata) {
  metadata_ = metadata;
  Publish();
}

void PageMedia::MediaSessionActionsChanged(const std::vector<media_session::mojom::MediaSessionAction>& actions) {
  actions_ = actions;
  Publish();
}

void PageMedia::MediaSessionImagesChanged(
    const base::flat_map<media_session::mojom::MediaSessionImageType, std::vector<media_session::MediaImage>>&) {}

void PageMedia::MediaSessionPositionChanged(const std::optional<media_session::MediaPosition>&) {}

void PageMedia::Publish() {
  changed_.Run();
  if (document_.empty()) {
    return;
  }
  using SessionState = media_session::mojom::MediaSessionInfo::SessionState;
  const bool engine_active = info_ && info_->state != SessionState::kInactive;
  if (engine_active) {
    seen_active_ = true;
    last_playing_ = info_->playback_state == media_session::mojom::MediaPlaybackState::kPlaying;
  }
  const bool active = engine_active || (info_ && seen_active_ && contents_->IsAudioMuted());
  engine::MediaSessionChanged session{
      .page_id = page_,
      .document = document_,
      .sequence = ++sequence_,
      .location = PresentedURL(contents_->GetLastCommittedURL()),
      .active = active,
      // While muted the engine reports no playback; the last state it did
      // report stands.
      .playback = !active        ? engine::MediaPlayback::kNone
                  : last_playing_ ? engine::MediaPlayback::kPlaying
                                  : engine::MediaPlayback::kPaused,
      .audible = contents_->IsCurrentlyAudible(),
      .muted = contents_->IsAudioMuted(),
  };
  if (metadata_) {
    session.title = Text(metadata_->title);
    session.artist = Text(metadata_->artist);
    session.album = Text(metadata_->album);
  }
  for (auto action : actions_) {
    switch (action) {
      case media_session::mojom::MediaSessionAction::kPlay:
        session.actions.push_back(engine::MediaSessionAction::kPlay);
        break;
      case media_session::mojom::MediaSessionAction::kPause:
        session.actions.push_back(engine::MediaSessionAction::kPause);
        break;
      case media_session::mojom::MediaSessionAction::kPreviousTrack:
        session.actions.push_back(engine::MediaSessionAction::kPreviousTrack);
        break;
      case media_session::mojom::MediaSessionAction::kNextTrack:
        session.actions.push_back(engine::MediaSessionAction::kNextTrack);
        break;
      default:
        break;
    }
  }
  present_.Run(std::move(session));
}

}  // namespace crest
