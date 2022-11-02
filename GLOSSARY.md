# Copier Python

A Copier template that renders Python (or non-Python) project scaffolding, plus the repo that renders itself from it.

## Language

**Release tag**:
An unprefixed version tag (e.g. `0.1.0`) on a commit; the only place a rendered project declares its version.
_Avoid_: version bump, `v`-prefixed tag

**Release version**:
The version of a build from a commit carrying a Release tag: the tag itself (`0.1.0`), with nothing appended.
_Avoid_: tagged version

**Dev version**:
The version of a build from any commit without a Release tag: the next patch, the commit distance and the commit hash (`0.1.1.dev3+445e8a3`).
_Avoid_: snapshot, local version
