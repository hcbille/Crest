namespace CrestCore.Contracts;

/// An answer to a question waiting on the person. A prompt lasts until the
/// person answers it, its engine withdraws it or its page goes, and is never
/// saved or synced.
public abstract record PromptIntent(Guid PromptId) : Intent;
