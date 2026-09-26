/// Commands and shortcut metadata supplied by the presenting platform shell.
@MainActor
struct BrowserCommandPaletteCommandRegistry {
    let commands: [ShortcutCommand]
    private let shortcutProvider: (ShortcutCommand) -> BrowserShortcut?
    private let performer: (ShortcutCommand) -> Void

    init(
        commands: [ShortcutCommand],
        shortcut: @escaping (ShortcutCommand) -> BrowserShortcut? = { _ in nil },
        perform: @escaping (ShortcutCommand) -> Void
    ) {
        self.commands = commands
        shortcutProvider = shortcut
        performer = perform
    }

    /// The commands as the palette ranks them, with the titles this device
    /// shows for them.
    var paletteCommands: [PaletteCommand] {
        commands.map {
            PaletteCommand(
                command: $0, title: $0.title(locale: .current), sectionTitle: $0.section.title(locale: .current))
        }
    }

    func shortcut(for command: ShortcutCommand) -> BrowserShortcut? {
        shortcutProvider(command)
    }

    func perform(_ command: ShortcutCommand) {
        performer(command)
    }
}
