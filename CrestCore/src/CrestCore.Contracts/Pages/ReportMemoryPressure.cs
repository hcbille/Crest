namespace CrestCore.Contracts;

/// The system asks for memory back at `Level`. The core unloads pages nobody
/// sees, off screen longest first, as many as the device's platform gives
/// back at that level. A page a window shows, one playing, capturing or in
/// Picture in Picture, one whose tab keeps its page loaded, and a Quick
/// Window's or Peek's page all stay.
public sealed record ReportMemoryPressure(MemoryPressureLevel Level) : PageIntent;
