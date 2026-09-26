import SwiftUI

struct MobileOnboardingLifecycleModifier: ViewModifier {
    let request: BrowserOnboardingRequest
    @Bindable var progress: BrowserOnboardingProgressStore
    /// Starts what the onboarding shows once it appears, since a view may be
    /// built more than once.
    let appeared: () -> Void
    let requestChanged: (BrowserOnboardingRequest) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: appeared)
            .task {
                if progress.isChecking {
                    await progress.refresh()
                }
            }
            .onChange(of: request) { _, request in
                requestChanged(request)
            }
            .interactiveDismissDisabled(request.entryPoint == .firstRun)
    }
}
