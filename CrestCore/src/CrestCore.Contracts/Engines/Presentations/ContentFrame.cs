namespace CrestCore.Contracts;

/// A frame of a page's document: the identity `EvaluateContentScript` takes,
/// whether it is the main frame, and the origin of what it shows.
public sealed record ContentFrame(string Id, bool IsMainFrame, string Protocol, string Host, int Port);
