# CLAUDE.md

A **Copier template** for Python projects, not an application. Everything under `template/` is rendered into *other* projects by `copier`; nothing there runs in place.

Canonical source is `git@github.com:fresh2dev/copier-python.git` (`origin` and `github` remotes); consumers pull the `dev` branch (`-r dev`). The root `README.md` is the user-facing usage doc; keep it in sync with the commands here.

## Commands

- `just test`: offline smoke test of all three variants (`python+docs`, `other+docs`, `other+no-docs`), ~10s, renders the uncommitted working tree.
- `just test-e2e`: network, a few minutes; run after touching any `*.just`/`justfile`, `pyproject.toml`, `mkdocs.yml`, or anything under `src/`/`tests/`.
- `prek run --all-files`: lint this repo (this stack uses `prek`, not `pre-commit`).
- Re-sync the repo root after committing template changes, then review `git diff` (especially `README.md`) and restore the hand-maintained parts:

  ```sh
  copier recopy --trust -r HEAD --exclude justfile --skip-answered
  ```

- Apply to a target project: `copier copy --trust -r dev git@github.com:fresh2dev/copier-python.git .` (update: `copier recopy --trust -r dev --skip 'src/**/*' --skip-answered`).

## Rules that apply everywhere

- Every copier invocation needs `--trust` (`_tasks` run `git init`, `prek install`, `mise trust`, `br init`).
- A non-interactive `--defaults` run must pass `--data license_type=...` (no default).
- `.beads/` is gitignored in rendered projects and here **on purpose**. Don't "fix" it.
- The repo root is rendered from its own `template/`; change template-owned root files through `template/` and a re-sync, not by hand. See [architecture](.claude/architecture.md#the-repo-root-renders-itself) for the hand-maintained exceptions.
- Issues: `br` tracker in `.beads/`; triage with `bv --robot-triage` (robot flags only).

## Detailed instructions

- [Architecture](.claude/architecture.md): `copier.yml` toggles, questions, computed values, rendered file map, `_tasks`, root self-render.
- [Template file conventions](.claude/template-conventions.md): `.jinja` suffix rules, conditional file names, gating content, hook-clean output.
- [Testing](.claude/testing.md): what `just test` and `just test-e2e` check.
- [Rendered project conventions](.claude/rendered-project.md): justfile split, tool pins, hooks, packaging, docs, CI, mise, changelog.
