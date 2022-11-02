# CLAUDE.md

## What this repo is

A **Copier template** for Python projects, not an application. Everything under `template/` is rendered into *other* projects by `copier`; nothing there runs in place. Validate changes with `just test` / `just test-e2e` (below).

Canonical source is `git@github.com:fresh2dev/copier-python.git` (both the `origin` and `github` remotes point there), and consumers pull the `dev` branch (`-r dev`). The root `README.md` is the user-facing usage doc; keep it in sync with the commands here.

## Architecture

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

Questions: `project_display_name`, `project_description`, `project_type`, `docs`, `repo_host`, `repo_owner`, `repo_ssh_url`, `home_domain`, `docs_route`, `license_type`, `python_version`, `author_name`, `author_email`. `license_type` has no default, so a non-interactive `--defaults` run must pass `--data license_type=...`. `python_version` is asked only for `project_type=python`, and `home_domain`/`docs_route` only when `docs` is on. Unasked questions aren't recorded in the answers file, but their defaults still feed the computed values. Questions with `when: false` are **computed values**, never prompted: `project_name`, `repo_name`, `repo_url`, `home_url`, `docs_url`, `funding_url`, `package_name`.

`_tasks` in `copier.yml` run `git init`, set the `origin`/`github` remotes, `prek install --force` (this stack uses `prek`, not `pre-commit`), and `br init` if `br` is installed and `.beads/` is absent. This is why every invocation needs `--trust`, and why `prek` must be installed (`br` is optional).

`.beads/` is gitignored in rendered projects **on purpose**. Don't "fix" this.

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

### Template file conventions

- The `.jinja` suffix is stripped at render time; files without it are copied verbatim.
- **Files carrying another tool's `{{ }}` syntax must not have the `.jinja` suffix**, or copier renders their placeholders as undefined variables (empty strings): `template/justfile`, `python.just`, `docs.just` (just interpolation) and `template/.cliff.toml` (git-cliff Tera). Keep copier values out of them. That's why the docs output dir lives in `mkdocs.yml` as `site_dir: "public{{docs_route}}"` rather than in the justfile. If such a file ever needs a copier value, wrap the rest in `{% raw %}`.
- `template/.pre-commit-config.yaml.jinja` keeps its suffix despite having no template variables, so `prek` in this repo does not discover `template/` as a workspace member and run the template's hooks against template sources.
- Paths are templated too: `template/src/{{package_name}}/...`.
- Conditional files use an empty-name trick: `template/{% if license_type == 'MIT' %}LICENSE{% endif %}` renders to nothing (and is skipped) when the condition is false. `license_type=Other` yields no `LICENSE`, and the build still succeeds. The same trick gates the toggles: on a directory it drops the whole subtree (`{% if docs %}docs{% endif %}/`), and on a `.jinja` file the tag goes before the suffix (`{% if project_type == 'python' %}pyproject.toml{% endif %}.jinja`). A conditional name doesn't make the content Jinja: without `.jinja`, the file is still copied verbatim.
- Gate content inside shared files (`.gitignore`, `README.md`, `mkdocs.yml`, `.pre-commit-config.yaml`) with inline `{% if %}` tags, placed so that no variant gets a stray blank line.
- Rendered files must pass the rendered project's own hooks (e.g. `end-of-file-fixer`), or the project's first commit is rejected. The answers-file template uses `to_nice_yaml -}}` for this reason. Rendered markdown must be `rumdl fmt`-clean in every variant: one blank line around headings, no double blank lines, a language on every code fence. Use `{%- if %}`/`{%- endif %}` so a skipped block doesn't leave a stray blank line.

## Commands

Apply the template to a target project (run from the target directory):

```sh
copier copy --trust -r dev git@github.com:fresh2dev/copier-python.git .

# update an already-templated project
copier recopy --trust -r dev --skip 'src/**/*' --skip-answered
```

`recopy` resets template-owned files that get hand-edited after generation (`README.md`, `justfile`); review `git diff` afterwards. `CHANGELOG.md` and `CLAUDE.md` are in `_skip_if_exists`, so they are rendered once and never overwritten (this also protects the root copies on re-sync).

Both test recipes run once per variant (`python+docs`, `other+docs`, `other+no-docs`), print a header per variant, and name the failing variants. Each variant has its own expected-present and expected-absent file lists in the root `justfile`.

Smoke test, `just test` (offline, ~10s). It renders `template/` from a VCS-free copy of the working tree, so uncommitted changes are tested; a plain `copier copy .` renders the last commit instead. Checks:

- expected files exist, and gated files are absent
- no unrendered `{{ }}`/`{% %}` survives (excluding `.cliff.toml`, `justfile` and `*.just`; a `{{` right after `$` is a GitHub Actions expression)
- the workflows match the variant: Python steps and the min/latest test matrix only for python, a `pypi`/`docs` release job per toggle, each needing `checks`
- rendered TOML, JSON and prek config parse
- `just --summary` lists exactly the enabled recipes, and multi-line tool variables interpolate inline (`--dry-run` of `changelog`, `lint`, `docs-build`)
- the docs `site_dir` matches the wrangler route (docs variants)
- the `_tasks` chain completes
- the rendered output passes its own prek hooks (`SKIP=lint`, which needs network; `format` runs dprint with this machine's config)

End-to-end test, `just test-e2e` (needs network, a few minutes; requires `dprint` and `mise` on `PATH`). Per variant, it renders the template, installs hooks, makes a real first commit (full hook set), and tags it. It then runs the rendered project's own recipes, as enabled:

- `format` (the whole tree must be clean under this machine's dprint config: no diff), `changelog`
- *(python)* `install`, `test`, `lint`, `check-types`, `check-docstrings`, `build` and a `publish-test` dry run
- *(docs)* `docs-build`
- `actionlint` on the rendered workflows
- a real `mise install` of the rendered `mise.toml`, the way CI's `jdx/mise-action` does it (`CI=true`, empty global config and data dir)

Run it after touching any `*.just`/`justfile`, `pyproject.toml`, `mkdocs.yml`, or anything under `src/`/`tests/`.

Lint this repo: `prek run --all-files`.

## Conventions in the rendered project

- **justfile split**: the core `justfile` holds `git_cliff`, `default`, `changelog` and `format`, and does `import? 'python.just'` / `import? 'docs.just'`. All three are copied verbatim (no `.jinja`); only their conditional file names decide whether the modules exist. Imports share one namespace, so recipe names must not repeat across files, and no recipe may depend on a recipe in another optional module (e.g. `clean` doesn't depend on `docs-clean`). Depending on core recipes is fine (`fix *args: && format`).
- **format**: `format *paths` runs `dprint fmt --allow-no-files "$@"`. The template ships no dprint config: dprint uses one found from the working directory up, else the global one, else does no formatting (exit 11 is tolerated). dprint and its config come from the machine, not pinned (CI doesn't format). Rendered files must be stable under the maintainer's config, or the first commit's `format` hook rejects them.
- **Tool pins**: tools are pinned in multi-line `'''` variables (`ruff`, `ty`, `pytest`, `zensical`, …). Close each string on its last command line (`-- ruff'''`). A closing `'''` on its own line leaves a trailing newline, so `{{ ruff }} check` runs as two shell commands.
- **Hooks**: the rendered `.pre-commit-config.yaml` runs `just format` on all staged files in every variant, and `just check ./src` (the `lint` hook) only for `project_type=python`. Keep the `format` and `check` recipe names stable.
- **Packaging** (python): `uv` for envs/locking, `hatchling` build backend. The version comes from git tags (unprefixed, e.g. `0.1.0`) via `uv-dynamic-versioning` (hatchling + dunamai), and `__init__.py` reads it back with `importlib.metadata.version(__name__)`; nothing is written into `src/`. A tagged commit builds exactly the tag (no `metadata = true`: PyPI rejects local versions); any other commit builds dunamai's dev version (`0.1.1.dev1+<hash>`). `[tool.uv] cache-keys` covers git commits and tags so editable installs pick up a new version. `uv version` can't read or set a dynamic version; see `docs/adr/0001-version-from-git-tags.md`. The CLI entrypoint is `yapx.run` in `__main__.py`.
- **Dependency groups**: `pytest` lives in the `tests` group (not only in the justfile's `--with`) so type checkers and IDEs resolve it from `.venv`. A `testpypi` index is defined for `just publish-test`.
- **Docs** (docs on): zensical has no output-dir flag. `site_dir` puts the build under `public{{docs_route}}`, wrangler serves `public/` at `{{home_domain}}{{docs_route}}*` (default `f2dv.com/r/<project-name>`), and `wrangler.toml` falls back to a custom-domain route when `docs_route` is empty. `docs/index.md`, `changelog.md` and `license.md` are `---8<---` snippet includes of the root `README.md`/`CHANGELOG.md`/`LICENSE`, so never edit them directly.
- **CI** (`.github/workflows/`): `checks.yml` runs prek on all files with `SKIP=format` (CI doesn't format; formatting is the commit hook's job), so it runs the builtin checks plus `lint` for python, and for python, `check-types`, `check-docstrings` and a `just test` matrix over `python_version` and the latest stable Python (`3.x`). CI pins nothing itself: every job installs the tools with `jdx/mise-action` (`CI=true` makes mise trust `mise.toml`) and runs recipes. Keep `ruff` in `mise.toml` in step with the `python.just` pin. `release.yml` triggers on unprefixed version tags and calls `checks.yml` through `workflow_call`; every publish job (`pypi`: `just publish` with trusted publishing, tags only; `docs`: `just docs-publish` with the Cloudflare secrets) must `needs: checks`. Both are `.jinja` files, so their `${{ }}` expressions sit inside `{% raw %}`.
- **Tools** (`mise.toml`): only CLIs the justfiles don't run through `uvx` / `uv run --with`. Versions are prefixes in the justfile style (`"0.16"` ≈ `==0.16.*`). dprint (and its config), copier and br come from the machine. wrangler is called as plain `wrangler` from `docs.just`. Locally, mise refuses the file until `mise trust`, and `just`/`prek` shims then fail in that directory.
- **Changelog**: `just changelog` prepends unreleased commits via git-cliff, grouped by conventional-commit type. `docs`/`style`/`build`/`ci`/`test` commits are skipped.

<!-- bv-agent-instructions-v7 -->

---

## Beads Workflow Integration

This project uses a Beads tracker—either the Go `bd` CLI or the Rust `br` CLI—for issue tracking, plus [beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) (`bv`) for graph-aware triage. Issues are stored in `.beads/`. `bv` auto-discovers supported JSONL exports, including `.beads/issues.jsonl` and legacy `.beads/beads.jsonl`.

**Choose the tracker CLI from this repository's instructions and configuration.** Use `bd` commands in a Go Beads workspace and `br` commands in a beads_rust workspace. Do not run both trackers against the same workspace or infer the tracker solely from the JSONL filename.

### Using bv as an AI sidecar

bv is a graph-aware triage engine for Beads projects. Instead of parsing .beads/issues.jsonl / .beads/beads.jsonl directly or hallucinating graph traversal, use robot flags for deterministic, dependency-aware outputs with precomputed metrics (PageRank, betweenness, critical path, cycles, HITS, eigenvector, k-core).

**Scope boundary:** bv handles *what to work on* (triage, priority, planning). The selected tracker CLI (`bd` or `br`) handles creating, claiming, modifying, and closing beads.

**CRITICAL: Use ONLY --robot-* flags. Bare bv launches an interactive TUI that blocks your session.**

#### The Workflow: Start With Triage

**`bv --robot-triage` is your single entry point.** Its `triage` object contains:

- `quick_ref`: at-a-glance counts + top 3 picks
- `recommendations`: ranked actionable items with scores, reasons, unblock info
- `quick_wins`: low-effort high-impact items
- `blockers_to_clear`: items that unblock the most downstream work
- `project_health`: status/type/priority distributions, graph metrics
- `commands`: copy-paste shell commands for next steps

```bash
bv --robot-triage        # THE MEGA-COMMAND: start here
bv --robot-next          # Minimal: just the single top pick + claim command

# TOON output (--format toon): a compact tabular encoding. Measured on this
# repository it is 7% smaller than JSON for --robot-graph but 9-15% LARGER for
# nested payloads (--robot-triage, --robot-plan, --robot-insights,
# --robot-label-health); use --stats to see both sizes before adopting it.
# TOON encoding shells out to the tru binary. With no encoder installed,
# --format toon prints a fallback warning, emits JSON with output_format "json",
# and --stats prints no sizes at all.
bv --robot-graph --format toon
bv --robot-triage --format toon --stats
```

Recommendations can include blocked or assigned work; `triage.quick_ref.top_picks` reflects snapshot readiness. A suggested action records its original local ID, working directory, and tracker route. Use that route rather than a namespaced display ID or an unrelated current directory. Inspect current tracker state before execution: analysis does not reserve work or guarantee that a later claim succeeds.

#### Other bv Commands

| Command | Returns |
|---------|---------|
| `--robot-plan` | Parallel execution tracks with unblocks lists |
| `--robot-priority` | Priority misalignment detection with confidence |
| `--robot-insights` | Full metrics: PageRank, betweenness, HITS, eigenvector, critical path, cycles, k-core |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, label suggestions, cycle breaks |
| `--robot-diff --diff-since <ref>` | Changes since ref: new/closed/modified issues |
| `--robot-graph [--graph-format=json\|dot\|mermaid]` | Dependency graph export |

Robot analysis commands default to JSON; `--format toon` selects TOON, and `--robot-help` defaults to text. In JSON mode, `--graph-format=dot` or `mermaid` puts diagram text in the `graph` field (`bv --robot-graph --graph-format=dot | jq -r .graph`).

#### Scoping & Filtering

```bash
bv --robot-plan --label backend              # Scope to label's subgraph
bv --robot-insights --as-of HEAD~30          # Historical point-in-time
bv --recipe actionable --robot-plan          # Pre-filter: ready to work (no blockers)
bv --recipe high-impact --robot-triage       # Pre-filter: top PageRank scores
```

### Tracker Commands for Issue Management

Use exactly one command family, matching the tracker configured for the repository.

#### Rust beads_rust (`br`)

Use `br` 0.6.0 or newer when executing saved claim commands. It rechecks
deferred status and future `defer_until` values when the claim runs, so a
recommendation captured before a deferral cannot bypass it. This requirement
applies to executing tracker claims.

```bash
br ready --json                       # Show issues ready to work (no blockers)
br list --status=open --json          # All open issues
br show <id> --json                   # Full issue details with dependencies
br create --title="..." --type=task --priority=2 --json
br update <id> --claim --json         # Claim for the current actor and start work
br close <id> --reason="Completed" --json
br close <id1> <id2> --reason="Completed" --json
br sync --flush-only                  # Export DB to JSONL after Beads mutations
```

#### Go Beads (`bd`)

```bash
bd ready --json                       # Show issues ready to work
bd show <id> --json                   # Full issue details
bd create "..." -t task -p 2 --json
bd update <id> --claim --json         # Atomically claim work
bd close <id> --json
bd dep add <issue> <depends-on>
bd export -o .beads/issues.jsonl        # Refresh the compatibility export read by bv
```

### Workflow Pattern

1. **Triage**: Run `bv --robot-triage` to find the highest-impact actionable work
2. **Verify**: Check the selected tracker's `show`/`ready` output before claiming
3. **Claim**: Use `br update <id> --claim --json` or `bd update <id> --claim --json`
4. **Work**: Implement the task
5. **Complete**: Use the selected tracker's `close` command
6. **Refresh for bv**: Run `br sync --flush-only` or the `bd export` command above so the JSONL export is current

### Key Concepts

- **Dependencies**: Issues can block other issues. `br ready --json` and `bd ready --json` show unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers 0-4, not words)
- **Types**: task, bug, feature, epic, chore, docs, question
- **Blocking**: Use `br dep add <issue> <depends-on>` or `bd dep add <issue> <depends-on>` to add dependencies

### Git Policy

Tracker commands do not grant permission to commit or push application code. Follow this repository's own git and tracker instructions before staging, committing, syncing, or pushing. If the repository says "commit only when asked," that rule overrides any generic workflow advice.

<!-- end-bv-agent-instructions -->
