namespace CrestCore.Contracts;

/// No route more fits: there are already `Maximum`.
public sealed record LinkRoutesFull(int Maximum) : Rejection;
