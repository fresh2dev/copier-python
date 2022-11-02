<div align="center">
  <h1>copier-python</h1>
  <hr>
  <p><em>A Copier template for [Python] projects.</em></p>
  <hr>
  <a href="https://f2dv.com/r/copier-python/">Documentation</a> |
  <a href="https://github.com/fresh2dev/copier-python/">Git Repo</a>
  <hr>
</div>

A [Copier](https://copier.readthedocs.io) template for starting and maintaining projects with a consistent layout and workflow. A single question set renders a ready-to-commit repository. You choose the project type and whether it has a docs site, and the template includes only the pieces that apply.

Every generated project gets task recipes, commit hooks, formatting, and changelog tooling. Python projects add packaging, tests, and quality checks. Projects with docs add a static site and its deployment.

## Usage

Generate a project from the new project's directory and answer the prompts:

```sh
copier copy --trust -r dev git@github.com:fresh2dev/copier-python.git .
```

`--trust` is required because the template runs post-copy tasks, such as initializing git and installing hooks. Those tasks expect their tools to be installed; see `_tasks` in [`copier.yml`](copier.yml).

Pull later template changes into an existing project:

```sh
copier recopy --trust -r dev --skip 'src/**/*' --skip-answered
```

Template-owned files are reset on recopy (except `CHANGELOG.md` and `CLAUDE.md`, which are never overwritten), so review `git diff` afterwards.

Answers are saved to `.copier-answers.yml`. For non-interactive runs, pass answers with `--data` and add `--defaults`.

## The generated project

Run `just --list` in the generated project to see its recipes. The recipes and hooks are the entry points; the tools behind them can change between template versions without changing how you use the project.

## Developing the template

The template lives in [`template/`](template/), and [`copier.yml`](copier.yml) holds the questions and post-copy tasks.

```sh
just test       # render the working tree and check the output (fast, offline)
just test-e2e   # also run each generated project's own recipes (slower, needs network)
```

See [`CLAUDE.md`](CLAUDE.md) for template conventions and pitfalls.

Run `mise trust && mise install` in the generated project to install the CLI tools pinned in `mise.toml` (dprint and its config come from your machine), then `just --list` to see its recipes. The recipes and hooks are the entry points; the tools behind them can change between template versions without changing how you use the project.

GitHub Actions install the same tools from `mise.toml` and run the same recipes. `.github/workflows/checks.yml` runs the linters (every git hook except the formatter) on pull requests and pushes to `main`; Python projects also run the tests on the minimum supported and the latest Python. Pushing a version tag (e.g. `0.1.0`) runs `.github/workflows/release.yml`, which runs those checks first and publishes only if they pass:

- Python projects publish to PyPI through trusted publishing. Register the repo, `release.yml` and the `pypi` environment as a trusted publisher on PyPI.
- Projects with docs deploy the site with wrangler. Set the `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` secrets.

## Developing the template

The template lives in `template/`; `copier.yml` holds the questions and post-copy tasks.

```sh
copier recopy --trust -r HEAD --exclude justfile --skip-answered
```

---

[![License](https://img.shields.io/github/license/fresh2dev/copier-python?color=blue&style=for-the-badge)](https://f2dv.com/r/copier-python/license/)
[![GitHub tag (with filter)](https://img.shields.io/github/v/tag/fresh2dev/copier-python?filter=!*%5Ba-z%5D*&style=for-the-badge&label=Release&color=blue)](https://f2dv.com/r/copier-python/changelog/)
[![GitHub last commit (branch)](https://img.shields.io/github/last-commit/fresh2dev/copier-python/main?style=for-the-badge&label=updated&color=blue)](https://f2dv.com/r/copier-python/changelog/)
[![GitHub Repo stars](https://img.shields.io/github/stars/fresh2dev/copier-python?color=blue&style=for-the-badge)](https://star-history.com/#fresh2dev/copier-python&Date)
<!-- [![Funding](https://img.shields.io/badge/funding-%24%24%24-blue?style=for-the-badge)](https://f2dv.com/fund/) -->
<!-- [![GitHub issues](https://img.shields.io/github/issues-raw/fresh2dev/copier-python?color=blue&style=for-the-badge)](https://github.com/fresh2dev/copier-python/issues/) -->
<!-- [![GitHub pull requests](https://img.shields.io/github/issues-pr-raw/fresh2dev/copier-python?color=blue&style=for-the-badge)](https://github.com/fresh2dev/copier-python/pulls/) -->
