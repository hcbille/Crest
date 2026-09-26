import Dispatch
import Foundation

/// The app's one memory pressure source on the Mac. Each squeeze first
/// releases what the page pools keep themselves, then tells the core, which
/// unloads the tab pages off screen longest.
@MainActor
final class BrowserMemoryPressureMonitor {
    // MARK: - Variables

    private weak var core: CrestCore?
    private let pools: BrowserPagePoolRegistry
    private var source: (any DispatchSourceMemoryPressure)?
    private var coalescer = BrowserMemoryPressureCoalescer()
    private var report: Task<Void, Never>?

    // MARK: - Initializers

    init(core: CrestCore, pools: BrowserPagePoolRegistry) {
        self.core = core
        self.pools = pools
    }

    // MARK: - Actions - Monitoring

    /// Starts following the system's memory pressure.
    func start() {
        guard source == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            // `dispatch_source_get_data` is only defined while this handler is
            // running: read after a hop it answers zero, and critical pressure
            // would forever look like a warning. The source runs on the main
            // queue, so the event is captured and handled without one.
            MainActor.assumeIsolated {
                guard let self, let source = self.source else { return }
                self.handle(source.data)
            }
        }
        self.source = source
        source.resume()
    }

    /// Handles one kernel pressure event, captured inside the source's own
    /// handler.
    func handle(_ event: DispatchSource.MemoryPressureEvent, at time: Date = .now) {
        relieve(event.contains(.critical) ? MemoryPressureLevel.critical : .warning, at: time)
    }

    /// Relieves one squeeze at `level`, once however many signals it sends.
    func relieve(_ level: MemoryPressureLevel, at time: Date = .now) {
        guard coalescer.shouldHandle(level, at: time) else { return }
        let pools = pools.livePools
        for pool in pools { pool.relieveMemoryPressure(level) }
        report?.cancel()
        report = Task { @MainActor [weak self] in
            // TRANSITIONAL until WP C (j1): WebKit tells the core what media a
            // page runs only when the page's Media Session bridge speaks, so
            // each WebKit page is asked now and the core decides on fresh media.
            var asked = Set<ObjectIdentifier>()
            for page in pools.flatMap(\.residentPages) where asked.insert(ObjectIdentifier(page)).inserted {
                await page.reportMediaActivity()
            }
            guard !Task.isCancelled, let core = self?.core else { return }
            _ = try? core.send(ReportMemoryPressure(level: level))
        }
    }

    /// Waits until the core heard the latest squeeze.
    func waitForReport() async {
        await report?.value
    }

    deinit {
        source?.cancel()
    }
}
