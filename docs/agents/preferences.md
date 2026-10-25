# Working preferences

How HC wants agents to work in this fork, on any machine. These rules add to
the rest of `AGENTS.md` and the `crest-contribution` skill.

## Branches and the fork

- Remotes: `fork` is `hcbille/Crest`, where branches are pushed; `origin` is
  `pauljoda/Crest`, which receives pull requests.
- The fork's `main` carries fork-only commits (the `## Agent skills` section
  of `AGENTS.md`, `docs/agents/`, `.claude/agents/`, and their ignore rules).
  Update it with `git pull --rebase`. It stays ahead of `origin/main` by those
  commits, and it is pushed only to `fork`.
- Start every new feature or fix on a fresh branch:
  `git switch -c <name> origin/main`. One pull request per branch. If the
  current branch belongs to other work or its PR is merged, branch first; if
  unrelated uncommitted changes are present, point them out before going on.
- Before opening a pull request to `origin`, check that
  `git log origin/main..HEAD` holds no fork-only commits.
- Notes on how HC builds locally (Chromium workspace, source upgrades) stay
  in the fork, as standalone files on a personal branch such as
  `hc/chromium-workspace-notes`, never in upstream docs like
  `ForkMaintenance.md` or in feature pull requests.

## Builds

- Prepare or build Chromium (`prepare-chromium.py`,
  `build-chromium-baseline.py`) only when HC expressly allows it in the
  current session. Otherwise do the read-only checks, say what a build would
  take (tree, preparation, disk), and ask. Earlier approval does not carry
  over.
- Start any build that may run over about an hour detached from the session,
  so a tool time limit cannot stop it:

  ```sh
  (PATH="/Users/Shared/CrestChromium/tools/bin:/opt/homebrew/bin:$PATH" \
    nohup caffeinate -i python3 Scripts/control-plane/build-chromium-baseline.py \
    --source <src> --ninja /Users/Shared/CrestChromium/tools/bin/ninja \
    --jobs 5 --min-free-gib 10 > <log> 2>&1 < /dev/null &)
  ```

  Confirm its parent is PID 1, then give HC the log path, a progress check
  (`grep -E '^\[[0-9]+/' <log> | tail -1`) and the stop command. Use
  `--jobs 5` for Chromium. If a build is stopped by a limit, restart it
  detached right away; ninja resumes.

## Verification

- HC verifies every change by hand. End implementation work with a numbered
  checklist: each step says what to do and the expected result, covering
  every behavior the change touches (normal and private windows, each
  affected engine). Wait for HC's results before committing or opening a
  pull request, and put those results in the pull request.
- To test beside HC's own Crest (`com.pauldavis.crest`, usually running),
  package a review copy with its own bundle ID: build the `CrestChromiumUI`
  scheme (not `CrestChromiumUIProduct`) and package it with
  `Scripts/control-plane/package-chromium-host.py` without `--product`. It
  becomes `com.pauldavis.crest.control-plane.chromium` ("Crest Chromium
  Experiment"), runs isolated with its own store, and signs with the Apple
  Development identity. When engine inputs are unchanged, download the
  published engine with
  `gh release download $(python3 Scripts/control-plane/chromium_engine.py tag) -R pauljoda/Crest`.
  Launch it detached with
  `CREST_ISOLATED_SESSION=1 "<app>/Contents/MacOS/Chromium" --crest-control-plane --user-data-dir=<own dir>`.
  It lacks the production entitlements (passkeys, the Apple Passwords
  helper), so checks of those need the product identity. Afterwards quit it,
  unregister it with `lsregister -u`, and delete it.

## Writing

- HC calls the link-preview overlay "Glance"; the code and product call it
  Peek (`BrowserPeek*`). Read "Glance" as Peek, not as a Quick Window, and
  write "Peek" in commits, branch names and pull request text.
- New UI reuses the design system in `CrestMac/DesignSystem`,
  `CrestMobile/DesignSystem` and `CrestShared/DesignSystem`. When a token or
  component is missing, extend the design system rather than styling inline.
- Edit repository JSON such as `Documentation/ReleaseNotes.json` as text
  (the Edit tool, or an insertion before the closing braces) so every other
  line stays byte-identical, then check `git diff --stat` shows only the
  added lines. Re-serializing it with a JSON library rewrites escapes in
  unrelated entries.
