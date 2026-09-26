namespace CrestCore.Contracts;

/// The Spaces `Source` brings, as `ReadImport` answered them, with where each
/// of its saved passwords belongs, from which setup counts the passwords that
/// belong with each Space. Setup reviews them: each Space joins
/// the existing Space of the same name, leaving out the tabs that Space holds,
/// or else comes in as a new Space, and the person looks at the first.
///
/// Refused with `InvalidImport` for Spaces that repeat an identity or hold a
/// split repair would rewrite.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ReviewImport(ImportSource Source, IReadOnlyList<SpaceState> Spaces, IReadOnlyList<ImportPasswordSource> Passwords)
    : SetupFlowIntent;
