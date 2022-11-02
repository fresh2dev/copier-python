# Architecture

How `copier.yml` and `template/` fit together, and how the repo root is rendered from itself.

## Rendering

`copier.yml` sets `_subdirectory: template/`, so one copier run renders the whole project. Answers land in `.copier-answers.yml` (copier's default `_answers_file`).

Two questions toggle whole stacks:

- **`project_type`** (`python` default / `other`) gates packaging, sources, tests, Python tooling (`python.just`) and the prek `lint` hook. `other` renders none of them.
- **`docs`** (bool, default `true`) gates the zensical/wrangler docs stack: `mkdocs.yml`, `wrangler.toml`, `docs/`, `docs.just`.

A rendered `python` + `docs` project gets (rows marked *(python)* / *(docs)* are gated):

| Area | Files |
|---|---|
| Packaging *(python)* | `pyproject.toml` (hatchling + uv-dynamic-versioning), `.python-version`, `README.pypi.md`, `src/{{package_name}}/`, `tests/` |
| Tasks | `justfile` (core), `python.just` *(python)*, `docs.just` *(docs)*; self-contained, pinned tools via `uvx` / `uv run --with` |
| Tools | `mise.toml`: CLI tools CI needs that the justfiles don't bootstrap via `uvx` (just, uv, prek, wrangler *(docs)*) |
| Quality | `.pre-commit-config.yaml` (prek), `renovate.json` |
| Docs *(docs)* | `mkdocs.yml` (built by **zensical**, which reads mkdocs config), `docs/`, `wrangler.toml` (Cloudflare Workers static assets) |
| Release | `.cliff.toml` (git-cliff), `CHANGELOG.md`, `README.md`, `LICENSE` |
| CI | `.github/workflows/checks.yml` (always), `.github/workflows/release.yml` *(python or docs)* |
| Repo | `.gitignore`, `.github/*`, `.env`, `CLAUDE.md` |

## Questions and computed values

Questions: `project_display_name`, `project_description`, `project_type`, `docs`, `repo_host`, `repo_owner`, `repo_ssh_url`, `home_domain`, `docs_route`, `license_type`, `python_version`, `author_name`, `author_email`.

- `license_type` has no default, so a non-interactive `--defaults` run must pass `--data license_type=...`.
- `python_version` is asked only for `project_type=python`; `home_domain`/`docs_route` only when `docs` is on. Unasked questions aren't recorded in the answers file, but their defaults still feed the computed values.
- Questions with `when: false` are **computed values**, never prompted: `project_name`, `repo_name`, `repo_url`, `home_url`, `docs_url`, `funding_url`, `package_name`.

## `_tasks`

`_tasks` in `copier.yml` run `git init`, set the `origin`/`github` remotes, `prek install --allow-missing-config --force` (this stack uses `prek`, not `pre-commit`), `mise trust` if `mise` is installed, and `br init` if `br` is installed and `.beads/` is absent. This is why every invocation needs `--trust`, and why `prek` must be installed (`mise` and `br` are optional).

`CHANGELOG.md` and `CLAUDE.md` are in `_skip_if_exists`, so they are rendered once and never overwritten (this also protects the root copies on re-sync).

## The repo root renders itself

The repo root is rendered from its own `template/` (`project_type=other`, `docs=true`, `license_type=MIT`; answers in the root `.copier-answers.yml`, `_src_path: .`). Template-owned root files (`.cliff.toml`, `renovate.json`, `.env`, `mise.toml`, `mkdocs.yml`, `wrangler.toml`, `docs/`, `docs.just`, `LICENSE`, `.github/*`) should change through `template/` and a re-sync, not by hand. The exceptions are hand-maintained:

- `justfile`: excluded from the render. Its top block is a verbatim copy of `template/justfile`; below it sit the hand-maintained `test`/`test-e2e` recipes.
- `README.md`: the header and badges come from the template; the body (usage and development docs) is hand-written.
- `CHANGELOG.md`: keeps the repo's own history (protected by `_skip_if_exists`).
- `.gitignore` adds `!template/**/*`, and `.pre-commit-config.yaml` adds the `check-executables-have-shebangs` / `check-shebang-scripts-are-executable` builtins.

Re-sync the root after committing template changes (`-r HEAD` renders the last commit), then review `git diff`, especially `README.md`, and restore the hand-maintained parts:

```sh
copier recopy --trust -r HEAD --exclude justfile --skip-answered
```

The repo's docs site builds with `just docs-build` and deploys to `f2dv.com/r/copier-python` via `just docs-publish`.
