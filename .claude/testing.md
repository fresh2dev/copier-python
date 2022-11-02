# Testing

Both test recipes live in the root `justfile`, run once per variant (`python+docs`, `other+docs`, `other+no-docs`), print a header per variant, and name the failing variants. Each variant has its own expected-present and expected-absent file lists in the root `justfile`.

## `just test` (smoke, offline, ~10s)

Renders `template/` from a VCS-free copy of the working tree, so uncommitted changes are tested; a plain `copier copy .` renders the last commit instead. Checks:

- expected files exist, and gated files are absent
- no unrendered `{{ }}`/`{% %}` survives (excluding `.cliff.toml`, `justfile` and `*.just`; a `{{` right after `$` is a GitHub Actions expression)
- the workflows match the variant: Python steps and the min/latest test matrix only for python, a `pypi`/`docs` release job per toggle, each needing `checks`
- rendered TOML, JSON and prek config parse
- `just --summary` lists exactly the enabled recipes, and multi-line tool variables interpolate inline (`--dry-run` of `changelog`, `lint`, `docs-build`)
- the docs `site_dir` matches the wrangler route (docs variants)
- the `_tasks` chain completes
- the rendered output passes its own prek hooks (`SKIP=lint`, which needs network; `format` runs dprint with this machine's config)

## `just test-e2e` (network, a few minutes)

Requires `dprint` and `mise` on `PATH`. Per variant, it renders the template, installs hooks, makes a real first commit (full hook set), and tags it. It then runs the rendered project's own recipes, as enabled:

- `format` (the whole tree must be clean under this machine's dprint config: no diff), `changelog`
- *(python)* `install`, `test`, `lint`, `check-types`, `check-docstrings`, `build` and a `publish-test` dry run
- *(docs)* `docs-build`
- `actionlint` on the rendered workflows
- a real `mise install` of the rendered `mise.toml`, the way CI's `jdx/mise-action` does it (`CI=true`, empty global config and data dir)

Run it after touching any `*.just`/`justfile`, `pyproject.toml`, `mkdocs.yml`, or anything under `src/`/`tests/`.

## Linting this repo

`prek run --all-files`.
