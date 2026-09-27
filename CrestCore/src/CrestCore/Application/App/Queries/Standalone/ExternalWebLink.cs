using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Whether another app, a drop, a Peek, a popup or a menu may hand Crest an
/// address as a web link: HTTP or HTTPS with a host. The address arrives as
/// the scheme and host the platform's own parser reported.
public sealed record ExternalWebLink(string? Scheme, string? Host) : StandaloneQuery<ExternalAddressVerdict> {
    #region Actions - Answering

    internal override ExternalAddressVerdict Answer(StandaloneContext context) => new(ExternalUrlPolicy.AcceptsWebLink(Scheme, Host));

    #endregion
}
