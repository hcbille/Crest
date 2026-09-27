using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Reading other browsers' data and Crest's own browser-data files, and
/// writing exports. Reading changes nothing and holds no lock, so the
/// platform asks away from the main thread while the core goes on; the Spaces
/// it reads reach a workspace only through `ImportSpaces` and the other
/// imports, which check them again.
internal sealed class Portability(IReadOnlyList<ImportSpaceNames>? names, IClock clock, IIdSource ids) {
    #region Actions - Queries

    public ImportedSpaces Answer(ReadImport query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(InstalledBrowser.Of(query.Source).Read(query.Profiles, Names(query.Source), ids, clock.Now));
    }

    public ImportedSpaces Answer(ReadArchive query) {
        ArgumentNullException.ThrowIfNull(query);
        var contents = ImportFile.Read(query.Path, BrowserDataFile.MaximumBytes, new ArchiveTooLarge(), new FileUnreadable());
        var now = clock.Now;
        return new([.. BrowserDataFile.Read(contents).Select(space => space.Materialize(ids, now))]);
    }

    /// The file `format` writes of `session`, exported now.
    public ExportedDocument Export(SessionState session, ExportFormat format) => ExportWriter.Of(format).Write(session, clock.Now);

    /// The names `source`'s Spaces take in the person's language, or its
    /// English names when the platform gave none.
    private ImportSpaceNames Names(ImportSource source) =>
        names?.FirstOrDefault(entry => entry.Source == source)
        ?? new(source, source.SpaceName ?? source.Title, source.NumberedSpaceName ?? source.Title);

    #endregion
}
