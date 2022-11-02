# Template file conventions

Rules for files under `template/`. They apply whenever you add, rename or edit a template file.

## The `.jinja` suffix

- The `.jinja` suffix is stripped at render time; files without it are copied verbatim.
- **Files carrying another tool's `{{ }}` syntax must not have the `.jinja` suffix**, or copier renders their placeholders as undefined variables (empty strings): `template/justfile`, `python.just`, `docs.just` (just interpolation) and `template/.cliff.toml` (git-cliff Tera). Keep copier values out of them. That's why the docs output dir lives in `mkdocs.yml` as `site_dir: "public{{docs_route}}"` rather than in the justfile. If such a file ever needs a copier value, wrap the rest in `{% raw %}`.
- `template/.pre-commit-config.yaml.jinja` keeps its suffix despite having no template variables, so `prek` in this repo does not discover `template/` as a workspace member and run the template's hooks against template sources.
- `.github/workflows/*.yml.jinja` are `.jinja` files, so their `${{ }}` expressions sit inside `{% raw %}`.

## Paths and conditional files

- Paths are templated too: `template/src/{{package_name}}/...`.
- Conditional files use an empty-name trick: `template/{% if license_type == 'MIT' %}LICENSE{% endif %}` renders to nothing (and is skipped) when the condition is false. `license_type=Other` yields no `LICENSE`, and the build still succeeds.
- The same trick gates the toggles: on a directory it drops the whole subtree (`{% if docs %}docs{% endif %}/`), and on a `.jinja` file the tag goes before the suffix (`{% if project_type == 'python' %}pyproject.toml{% endif %}.jinja`).
- A conditional name doesn't make the content Jinja: without `.jinja`, the file is still copied verbatim.

## Gating content inside shared files

Gate content inside shared files (`.gitignore`, `README.md`, `mkdocs.yml`, `.pre-commit-config.yaml`) with inline `{% if %}` tags, placed so that no variant gets a stray blank line. Use `{%- if %}`/`{%- endif %}` so a skipped block doesn't leave a stray blank line.

## Rendered output must pass its own hooks

Rendered files must pass the rendered project's own hooks (e.g. `end-of-file-fixer`), or the project's first commit is rejected.

- The answers-file template uses `to_nice_yaml -}}` for this reason.
- Rendered markdown must be `rumdl fmt`-clean in every variant: one blank line around headings, no double blank lines, a language on every code fence.
- Rendered files must be stable under the maintainer's dprint config, or the first commit's `format` hook rejects them.
