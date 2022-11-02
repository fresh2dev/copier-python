# ─────────────────────────────────────────────────────────────────────────────
# Tools
# ─────────────────────────────────────────────────────────────────────────────

zensical := '''
    uv run \
    --with 'zensical>=0.0.67' \
    --with 'markdown-exec[ansi]==1.*' \
    --with 'mkdocstrings[python]>=1' \
    -- zensical'''

# wrangler is pinned in mise.toml.

# ─────────────────────────────────────────────────────────────────────────────
# Docs
# ─────────────────────────────────────────────────────────────────────────────

docs-serve:
    {{ zensical }} serve

docs-clean dir="public":
    rm -rf "{{ dir }}" .wrangler/

# Output dir is `site_dir` in mkdocs.yml (public + docs_route).
docs-build: docs-clean
    {{ zensical }} build

docs-upload: docs-build
    wrangler versions upload

docs-publish: docs-build
    wrangler deploy
