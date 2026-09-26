namespace CrestCore.Contracts;

/// Marks a record that holds a password or a file of them. The core keeps no
/// such record: none is reachable from a change, the session it stores or the
/// sync journal, and its text form names no secret. A containment test
/// checks both.
[AttributeUsage(AttributeTargets.Class, Inherited = false)]
public sealed class HoldsSecretsAttribute : Attribute;
