# CrestCore source layout

CrestCore is the portable browser control plane. The projects have distinct
responsibilities:

| Project | Responsibility |
| --- | --- |
| `CrestCore.Domain` | Tab and Space behavior, durable state, navigation, and sync policy. No JSON or native dependencies. |
| `CrestCore.Contracts` | The typed contract records (intents, changes, rejections, queries, engine commands and events, and the read models they carry), plus the JSON protocol validation policy requests use. |
| `CrestCore.Application` | Session commands, the session file, imports, and sync transitions. It owns the JSON-backed native and persistence formats and the SQLite file they are stored in, calls typed domain rules, and handles each message family through its generated handler interface. |
| `CrestCore.Native` | C exports that adapt native callers to the application layer, and the generated wire codec. |
| `tools/CrestCore.Generator` | Generates the codec, the core's handler interfaces, the Swift models and handling protocols, the C tag header and the C++ engine codec from the contract records. |
| `CrestCore.Tests` | Behavioral contracts for the corresponding source areas. |

Source folders follow the browser concepts they own. In the domain, `Tabs`
contains tab state and its batch, lifecycle, and organization rules; `Spaces`
contains Space ownership and preferences; `State` contains durable snapshots;
`Sync` contains portable record policy; `Navigation` contains URL, link, and
history rules; and `Identity` contains shared time and ID sources. Domain
objects use named `Guid` properties for identities without adding one-field wrappers.
The application groups session operations, sync operations, and status
separately, and gives each other browser area it serves, such as downloads,
credentials, or portability, a folder of its own. A type with behavior has its
own file, and partial classes keep related operations together under the
owning type's name. An area that receives a family of messages implements
that family's generated handler interface, and its per-case methods are the
`Handle` overloads; a small record, such as `PageTurn`, carries what each call
needs. Data-only records and enums share their concept's file, such as
`Windows/WindowMessages.cs`, or sit in a `Types` region at the top of the one
type that uses them.

Keep typed domain objects inside the control plane. Decode JSON at an input
boundary, apply browser rules through domain objects, then encode JSON at an
output boundary. The application layer retains JSON when preserving the native
session and sync formats. Preserve the existing protocol and C ABI when moving
source files. File-scoped namespaces remain stable across folders so native
callers and existing assemblies do not need new type names.

The repository `.editorconfig` controls C# layout, including same-line opening
braces. Run `Scripts/control-plane/lint-dotnet.sh` and the .NET tests before
committing changes. App-code commits also need a patch version and a release
note entry as described in the repository instructions.
