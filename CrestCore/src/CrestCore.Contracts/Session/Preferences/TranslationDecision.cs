namespace CrestCore.Contracts;

/// The rule that applies to a source language, or null, and the language its
/// pages are translated into, or null when they are not.
public sealed record TranslationDecision(TranslationRule? Rule, string? Target);
