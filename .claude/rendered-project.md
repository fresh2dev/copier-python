# Conventions in the rendered project

What a project generated from this template looks like, and the invariants to keep when editing `template/`.

## justfile split

The core `justfile` holds `git_cliff`, `default`, `changelog` and `format`, and does `import? 'python.just'` / `import? 'docs.just'`. All three are copied verbatim (no `.jinja`); only their conditional file names decide whether the modules exist.

- Imports share one namespace, so recipe names must not repeat across files.
- No recipe may depend on a recipe in another optional module (e.g. `clean` doesn't depend on `docs-clean`). Depending on core recipes is fine (`fix *args: && format`).
- **Tool pins**: tools are pinned in multi-line `'''` variables (`ruff`, `ty`, `pytest`, `zensical`, …). Close each string on its last command line (`-- ruff'''`). A closing `'''` on its own line leaves a trailing newline, so `{{ ruff }} check` runs as two shell commands.

## format

`format *paths` runs `dprint fmt --allow-no-files "$@"`. The template ships no dprint config: dprint uses one found from the working directory up, else the global one, else does no formatting (exit 11 is tolerated). dprint and its config come from the machine, not pinned (CI doesn't format). Rendered files must be stable under the maintainer's config, or the first commit's `format` hook rejects them.

## Hooks

The rendered `.pre-commit-config.yaml` runs `just format` on all staged files in every variant, and `just check ./src` (the `lint` hook) only for `project_type=python`. Keep the `format` and `check` recipe names stable.

## Packaging (python)

- `uv` for envs/locking, `hatchling` build backend.
- The version comes from git tags (unprefixed, e.g. `0.1.0`) via `uv-dynamic-versioning` (hatchling + dunamai), and `__init__.py` reads it back with `importlib.metadata.version(__name__)`; nothing is written into `src/`.
- A tagged commit builds exactly the tag (no `metadata = true`: PyPI rejects local versions); any other commit builds dunamai's dev version (`0.1.1.dev1+<hash>`).
- `[tool.uv] cache-keys` covers git commits and tags so editable installs pick up a new version.
- `uv version` can't read or set a dynamic version; see `docs/adr/0001-version-from-git-tags.md`.
- The CLI entrypoint is `yapx.run` in `__main__.py`.
- **Dependency groups**: `pytest` lives in the `tests` group (not only in the justfile's `--with`) so type checkers and IDEs resolve it from `.venv`. A `testpypi` index is defined for `just publish-test`.

## Docs (docs on)

- zensical has no output-dir flag. `site_dir` puts the build under `public{{docs_route}}`, wrangler serves `public/` at `{{home_domain}}{{docs_route}}*` (default `f2dv.com/r/<project-name>`), and `wrangler.toml` falls back to a custom-domain route when `docs_route` is empty.
- `docs/index.md`, `changelog.md` and `license.md` are `---8<---` snippet includes of the root `README.md`/`CHANGELOG.md`/`LICENSE`, so never edit them directly.

## CI (`.github/workflows/`)

- `checks.yml` runs prek on all files with `SKIP=format` (CI doesn't format; formatting is the commit hook's job), so it runs the builtin checks plus `lint` for python, and for python, `check-types`, `check-docstrings` and a `just test` matrix over `python_version` and the latest stable Python (`3.x`).
- CI pins nothing itself: every job installs the tools with `jdx/mise-action` (`CI=true` makes mise trust `mise.toml`) and runs recipes. Keep `ruff` in `mise.toml` in step with the `python.just` pin.
- `release.yml` triggers on unprefixed version tags and calls `checks.yml` through `workflow_call`; every publish job (`pypi`: `just publish` with trusted publishing, tags only; `docs`: `just docs-publish` with the Cloudflare secrets) must `needs: checks`.
- Both are `.jinja` files, so their `${{ }}` expressions sit inside `{% raw %}`.

## Tools (`mise.toml`)

Only CLIs the justfiles don't run through `uvx` / `uv run --with`. Versions are prefixes in the justfile style (`"0.16"` ≈ `==0.16.*`). dprint (and its config), copier and br come from the machine. wrangler is called as plain `wrangler` from `docs.just`. Locally, mise refuses the file until `mise trust` (a copier `_tasks` step runs it when `mise` is installed); until then `just`/`prek` shims fail in that directory.

## Changelog

`just changelog` prepends unreleased commits via git-cliff, grouped by conventional-commit type. `docs`/`style`/`build`/`ci`/`test` commits are skipped.
