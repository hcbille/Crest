namespace CrestCore.Contracts;

/// Whether Crest opens an address as a local document, from the facts the
/// platform's own parser reported. Only document-open routes ask.
public sealed record ExternalLocalDocument(LocalDocumentFacts Facts) : Query<ExternalAddressVerdict>;
