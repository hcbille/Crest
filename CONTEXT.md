# Crest

Crest is a browser that keeps browsing state in a shared core and renders
pages through interchangeable engines. This glossary names the concepts the
product and its code share.

## Language

### Developer Mode

**Developer Mode**:
The state in which a page shows Crest's developer tools for building and
testing sites.
_Avoid_: dev mode, developer toolbar (when meaning the state)

**Developer Toolbar**:
The bar Developer Mode shows above a page, holding viewport presets,
captures and inspector panels.
_Avoid_: dev toolbar, developer mode (when meaning the bar)

**Developer Toolbar Setting**:
The app-wide setting that decides where Developer Mode turns on by itself:
Off, On local pages (the default) or On all websites. It is stored once for
the app, never per site.
_Avoid_: developer mode preference, localhost setting

**Automatic Developer Mode**:
Developer Mode a page gets from the Developer Toolbar Setting: on local pages
(localhost, private addresses, `.local`, `.test`, files) in the local mode, or
on any http or https page in the all-websites mode. Internal pages never get
it.
_Avoid_: localhost mode

**Manual Developer Mode**:
Developer Mode shown or hidden for a single page by ⌘⇧I or by clicking the
Developer Mode row in Site Settings. It wins over Automatic Developer Mode in
every setting, is not saved, and lasts for the life of that page, including
after it navigates to another site. Hiding the toolbar also clears the
viewport preset.
_Avoid_: one-off Developer Mode, temporary toggle, per-site override

### Sites

**Site Origin**:
A site as scheme, host and port together, so `http://localhost:3000` and
`http://localhost:5173` are different sites.
_Avoid_: domain, host (when the port or scheme matters)

**Site Controls**:
The popover opened from the control at the right of the address field,
holding quick actions and Site Settings for the current site.
_Avoid_: page options menu, URL bar menu

**Site Settings**:
The section of Site Controls for the current page and its site: Developer
Mode, the engine the site opens in, permissions and security.
_Avoid_: site preferences
