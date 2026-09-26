namespace CrestCore.Contracts;

/// How a review heads each Space an import brings: with the Space's own name
/// and look, or with a plain section label, for a browser whose Spaces are
/// sections of one sidebar.
public enum ImportSpaceHeaderStyle {
    Identity,
    SectionLabel
}
