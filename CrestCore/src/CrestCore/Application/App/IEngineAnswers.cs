using CrestCore.Contracts;

namespace CrestCore.Application;

/// Answers the questions engine bindings ask about their pages while their
/// engines wait. An app answers every question, from its state, and changes
/// nothing.
public interface IEngineAnswers {
    #region Abstract Methods

    /// The answer to what `engine` asks about one of its pages.
    TAnswer Ask<TAnswer>(Engine engine, EngineQuestion<TAnswer> question);

    #endregion
}
