using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// The server a credential prompt names: its host, port and scheme. The host
/// may be empty.
public sealed record AuthenticationSource(string Host, int Port, string? Scheme) : StandaloneQuery<AuthenticationSourceLabel> {
    #region Actions - Answering

    internal override AuthenticationSourceLabel Answer(StandaloneContext context) =>
        new(AuthenticationPolicy.SourceLabel(Host, Port, Scheme));

    #endregion
}
