# ─────────────────────────────────────────────────────────────────────────────
# Tools
# ─────────────────────────────────────────────────────────────────────────────

git_cliff := '''
    uvx --from 'git-cliff==2.*' \
    -- git-cliff'''

# ─────────────────────────────────────────────────────────────────────────────
# Modules (present only when enabled for this project)
# ─────────────────────────────────────────────────────────────────────────────

import? 'python.just'
import? 'docs.just'

# ─────────────────────────────────────────────────────────────────────────────
# Default
# ─────────────────────────────────────────────────────────────────────────────

[positional-arguments]
default:
    @ just --choose

# ─────────────────────────────────────────────────────────────────────────────
# Core
# ─────────────────────────────────────────────────────────────────────────────

[positional-arguments]
changelog:
    {{ git_cliff }} --unreleased --prepend CHANGELOG.md

# Uses the dprint config found from here up, else the global one (exit 11: none, so nothing to format).
[positional-arguments]
format *paths:
    dprint fmt --allow-no-files "$@" || [ $? -eq 11 ]

# ─────────────────────────────────────────────────────────────────────────────
# Template tests (hand-maintained; not rendered from template/)
# ─────────────────────────────────────────────────────────────────────────────

# Functional smoke test: render each template variant and assert the output is sane (offline, ~10s).
test:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC="$(pwd)"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT

    # Render from a VCS-free copy so the working tree is tested, not the last commit.
    mkdir -p "$WORK/tmpl"
    tar -C "$SRC" --exclude=.git --exclude=public -cf - . | tar -C "$WORK/tmpl" -xf -

    # Variants: a name plus the extra copier --data args that select it.
    VARIANTS='python+docs other+docs other+no-docs'
    variant_data() {
        case "$1" in
            python+docs) echo '--data project_type=python --data docs=true' ;;
            other+docs) echo '--data project_type=other --data docs=true' ;;
            other+no-docs) echo '--data project_type=other --data docs=false' ;;
            *) echo "unknown variant: $1" >&2; return 1 ;;
        esac
    }
    # Files every variant must render (non-empty unless listed in EMPTY_FILES).
    present_files() {
        echo README.md LICENSE CHANGELOG.md .gitignore .pre-commit-config.yaml .env \
            .copier-answers.yml .github/CODEOWNERS .github/FUNDING.yml renovate.json \
            .cliff.toml justfile CLAUDE.md .github/workflows/checks.yml mise.toml
        case "$1" in python+*) echo pyproject.toml .python-version README.pypi.md \
            src/smoke_test/__init__.py src/smoke_test/__main__.py \
            src/smoke_test/py.typed tests/conftest.py tests/test_main.py tests/resources/.gitkeep python.just ;; esac
        case "$1" in *+docs) echo wrangler.toml mkdocs.yml docs.just \
            docs/index.md docs/changelog.md docs/license.md ;; esac
        case "$1" in python+docs) echo docs/reference/01.md ;; esac
        case "$1" in python+*|*+docs) echo .github/workflows/release.yml ;; esac
    }
    # Files a variant must not render.
    absent_files() {
        case "$1" in other+*) echo pyproject.toml .python-version README.pypi.md src tests python.just \
            docs/reference ;; esac
        case "$1" in *+no-docs) echo mkdocs.yml wrangler.toml docs docs.just ;; esac
        case "$1" in other+no-docs) echo .github/workflows/release.yml ;; esac
    }
    EMPTY_FILES=' CHANGELOG.md .env src/smoke_test/py.typed tests/resources/.gitkeep '

    fails=0
    failed_variants=''
    variant=''
    pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
    fail() {
        printf '  \033[31mFAIL\033[0m [%s] %s\n' "$variant" "$1"; fails=$((fails + 1))
        case " $failed_variants " in *" $variant "*) ;; *) failed_variants="$failed_variants $variant" ;; esac
    }
    check() { # check <label> <command>...
        local label="$1"; shift
        if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
    }
    section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

    render() { # render <dest> [extra copier args...]
        local dest="$1"; shift
        copier copy -q --trust --defaults \
            --data 'project_display_name=Smoke Test' \
            --data 'project_description=Smoke test render.' \
            --data license_type=MIT \
            $(variant_data "$variant") \
            "$@" "$WORK/tmpl" "$dest"
    }

    for variant in $VARIANTS; do
        printf '\n\033[1;36m== variant: %s ==\033[0m\n' "$variant"
        python=false; docs=false
        case "$variant" in python+*) python=true ;; esac
        case "$variant" in *+docs) docs=true ;; esac

        vdir="$WORK/$variant"
        out="$vdir/out"
        mkdir -p "$vdir"
        if ! render "$out" --skip-tasks >"$vdir/render.log" 2>&1; then
            fail "copier render failed"; sed 's/^/       /' "$vdir/render.log"; continue
        fi

        section files
        for f in $(present_files "$variant"); do
            case "$EMPTY_FILES" in
                *" $f "*) if [ -f "$out/$f" ]; then pass "$f (empty by design)"; else fail "$f missing"; fi ;;
                *) if [ -s "$out/$f" ]; then pass "$f"; else fail "$f missing or empty"; fi ;;
            esac
        done
        for f in $(absent_files "$variant"); do
            if [ -e "$out/$f" ]; then fail "$f should not be rendered"; else pass "$f absent"; fi
        done

        section rendering
        # These are copied verbatim and carry another tool's template syntax:
        # .cliff.toml is a git-cliff Tera template, justfile and *.just use just's own interpolation.
        # A double brace right after `$` is a GitHub Actions expression in a workflow, not a leak.
        leaked="$(grep -rlE '(^|[^$])\{\{|\{%' "$out" --exclude-dir=.git \
            | grep -vE '/(\.cliff\.toml|justfile|[^/]*\.just)$' || true)"
        if [ -z "$leaked" ]; then pass "no unrendered Jinja"
        else fail "unrendered Jinja in: $(echo "$leaked" | tr '\n' ' ')"; fi

        if grep -q '^project_type: ' "$out/.copier-answers.yml" \
            && grep -q '^docs: ' "$out/.copier-answers.yml"
        then pass "answers file records project_type and docs"
        else fail "answers file is missing project_type or docs"; fi

        if $python; then
            if grep -q '^name = "smoke-test"$' "$out/pyproject.toml"; then pass "project_name derived as smoke-test"
            else fail "project_name not derived from project_display_name"; fi
        fi

        if $docs; then
            if grep -q '^site_dir: "public/r/smoke-test"$' "$out/mkdocs.yml" \
                && grep -q 'pattern = "f2dv.com/r/smoke-test\*"' "$out/wrangler.toml"
            then pass "docs site_dir matches the wrangler route"
            else fail "mkdocs site_dir and wrangler route disagree"; fi
        else
            if ! grep -qE 'Documentation|f2dv\.com/r/' "$out/README.md"; then pass "README.md does not link to the docs site"
            else fail "README.md still links to the docs site"; fi
            if grep -q 'blob/main/LICENSE' "$out/README.md" && grep -q 'blob/main/CHANGELOG.md' "$out/README.md"
            then pass "README.md badges link to LICENSE and CHANGELOG.md in the repo"
            else fail "README.md badges do not link to the repo's LICENSE/CHANGELOG.md"; fi
        fi

        if ! $python; then
            if ! grep -q '^# Python$' "$out/.gitignore"; then pass ".gitignore has no Python block"
            else fail ".gitignore still has the Python block"; fi
            if ! grep -qiE 'pip install|pypi' "$out/README.md"; then pass "README.md has no pip install or PyPI badge"
            else fail "README.md still mentions pip install or PyPI"; fi
            if $docs; then
                if ! grep -qE 'mkdocstrings|reference/|\./src' "$out/mkdocs.yml"; then pass "mkdocs.yml has no Python reference/watch/mkdocstrings"
                else fail "mkdocs.yml still references Python sources"; fi
            fi
        fi

        # wrangler only deploys the docs.
        if [ "$(grep -c '^wrangler = ' "$out/mise.toml")" = "$($docs && echo 1 || echo 0)" ]
        then pass "mise.toml installs wrangler only with docs"
        else fail "mise.toml wrangler entry does not match docs=$docs"; fi

        section workflows
        wf="$out/.github/workflows"
        if grep -q '^          SKIP: format$' "$wf/checks.yml"; then pass "checks.yml skips the format hook"
        else fail "checks.yml runs the format hook"; fi
        if $python; then
            if grep -q 'python-version: \["3.11", "3.x"\]' "$wf/checks.yml"; then pass "checks.yml tests the minimum and latest Python"
            else fail "checks.yml does not test python_version and 3.x"; fi
        else
            if ! grep -qE '^  test:|check-types|python-version' "$wf/checks.yml"; then pass "checks.yml has no Python steps"
            else fail "checks.yml still has Python steps"; fi
        fi
        if [ -e "$wf/release.yml" ]; then
            for job in pypi docs; do
                if [ "$job" = pypi ]; then enabled=$python; else enabled=$docs; fi
                if grep -q "^  $job:" "$wf/release.yml"; then
                    if $enabled; then pass "release.yml job $job"; else fail "release.yml job $job should not be defined"; fi
                else
                    if $enabled; then fail "release.yml job $job missing"; else pass "release.yml job $job absent"; fi
                fi
            done
            # Nothing may publish before checks.yml passes.
            if [ "$(grep -cE '^  (pypi|docs):' "$wf/release.yml")" = "$(grep -c '^    needs: checks$' "$wf/release.yml")" ]
            then pass "every release.yml publish job needs checks"
            else fail "a release.yml publish job does not need checks"; fi
        fi

        section parsing
        for f in pyproject.toml wrangler.toml .cliff.toml mise.toml; do
            [ -e "$out/$f" ] || continue
            check "$f is valid TOML" python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$out/$f"
        done
        check "renovate.json is valid JSON" python3 -c 'import sys,json; json.load(open(sys.argv[1]))' "$out/renovate.json"
        check ".pre-commit-config.yaml is a valid prek config" prek validate-config "$out/.pre-commit-config.yaml"
        check "justfile parses" just --justfile "$out/justfile" --summary

        section recipes
        summary=" $(just --justfile "$out/justfile" --summary 2>/dev/null || true) "
        core_recipes='default changelog format'
        python_recipes='install fix lint check-types check-docstrings test build publish publish-test clean'
        docs_recipes='docs-serve docs-clean docs-build docs-upload docs-publish'
        expect_recipes() { # expect_recipes <enabled> <recipe>...
            local enabled="$1" r; shift
            for r in "$@"; do
                case "$summary" in
                    *" $r "*) if $enabled; then pass "recipe $r"; else fail "recipe $r should not be defined"; fi ;;
                    *) if $enabled; then fail "recipe $r missing"; else pass "recipe $r absent"; fi ;;
                esac
            done
        }
        expect_recipes true $core_recipes
        expect_recipes $python $python_recipes
        expect_recipes $docs $docs_recipes

        # Multi-line tool variables must not end in a newline, or `ruff` + ` check`
        # run as two separate shell commands.
        dry_run() { # dry_run <recipe> <expected substring>
            if (cd "$out" && just --dry-run "$1" 2>&1) | grep -q -- "$2"; then
                pass "just --dry-run $1 interpolates '$2' inline"
            else fail "just --dry-run $1 does not run '$2' (tool variable split across lines?)"; fi
        }
        dry_run changelog '-- git-cliff'
        if $python; then dry_run lint '-- ruff check'; fi
        if $docs; then dry_run docs-build '-- zensical build'; fi

        section _tasks
        taskdest="$vdir/out-tasks"
        if render "$taskdest" >/dev/null 2>&1 \
            && [ -e "$taskdest/.git/hooks/pre-commit" ] \
            && [ "$(git -C "$taskdest" remote get-url origin)" = 'git@github.com:fresh2dev/smoke-test.git' ]
        then pass "_tasks ran: git init, remotes, prek install, br init (if installed)"
        else fail "_tasks chain failed (git init / remotes / prek install / br init)"; continue; fi

        # A fresh project must pass its own hooks, or the first commit is rejected.
        # format runs through dprint with this machine's config; lint shells out to uvx (network),
        # so `just test-e2e` covers it.
        git -C "$taskdest" add -A
        if (cd "$taskdest" && SKIP=lint prek run --all-files) >"$vdir/prek.log" 2>&1; then
            pass "rendered output passes its own prek hooks"
        else
            fail "rendered output fails its own prek hooks"; sed 's/^/       /' "$vdir/prek.log" | grep -vE 'Passed|Skipped'
        fi
    done

    printf '\n'
    if [ "$fails" -eq 0 ]; then printf '\033[32mall checks passed (%s)\033[0m\n' "$VARIANTS"; else
        printf '\033[31m%s check(s) failed in:%s\033[0m\n' "$fails" "$failed_variants"; exit 1; fi

# End-to-end test: render each variant, then run the rendered project's own recipes (needs network, ~1min).
test-e2e:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC="$(pwd)"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT

    mkdir -p "$WORK/tmpl"
    tar -C "$SRC" --exclude=.git --exclude=public -cf - . | tar -C "$WORK/tmpl" -xf -

    # `just format` runs dprint (with this machine's config).
    for tool in dprint mise; do
        command -v "$tool" >/dev/null || { echo "test-e2e: '$tool' is not on PATH; install it first." >&2; exit 1; }
    done

    # Variants: a name plus the extra copier --data args that select it.
    VARIANTS='python+docs other+docs other+no-docs'
    variant_data() {
        case "$1" in
            python+docs) echo '--data project_type=python --data docs=true' ;;
            other+docs) echo '--data project_type=other --data docs=true' ;;
            other+no-docs) echo '--data project_type=other --data docs=false' ;;
            *) echo "unknown variant: $1" >&2; return 1 ;;
        esac
    }

    fails=0
    failed_variants=''
    variant=''
    step() { # step <label> <command>...
        local label="$1"; shift
        if "$@" >"$WORK/step.log" 2>&1; then
            printf '  \033[32mok\033[0m   %s\n' "$label"
        else
            printf '  \033[31mFAIL\033[0m [%s] %s\n' "$variant" "$label"; sed 's/^/       /' "$WORK/step.log" | tail -20
            fails=$((fails + 1))
            case " $failed_variants " in *" $variant "*) ;; *) failed_variants="$failed_variants $variant" ;; esac
        fi
    }

    # uv-dynamic-versioning reads the version from git tags.
    # The commit runs the full hook set, so a project that rejects its own first commit fails here.
    first_commit() {
        git init -q
        prek install -q
        git add -A
        git -c user.name=smoke -c user.email=smoke@example.com commit -q -m 'feat: init'
        git tag 0.1.0
    }

    # A commit past the release tag must rebuild the editable install with its dev version.
    dev_version() {
        git -c user.name=smoke -c user.email=smoke@example.com commit -q --allow-empty --no-verify -m 'feat: dev'
        local want got
        want="0.1.1.dev1+$(git rev-parse HEAD | cut -c1-7)"
        got="$(uv run smoke-test --version | awk '{print $NF}')"
        echo "want $want, got $got"
        [ "$got" = "$want" ]
    }

    for variant in $VARIANTS; do
        printf '\n\033[1;36m== variant: %s ==\033[0m\n' "$variant"
        python=false; docs=false
        case "$variant" in python+*) python=true ;; esac
        case "$variant" in *+docs) docs=true ;; esac

        out="$WORK/$variant"
        step "copier render" copier copy -q --trust --defaults --skip-tasks \
            --data 'project_display_name=Smoke Test' \
            --data 'project_description=Smoke test render.' \
            --data license_type=MIT \
            $(variant_data "$variant") \
            "$WORK/tmpl" "$out"
        [ -d "$out" ] || continue
        cd "$out"

        step "first commit passes the full hook set" first_commit
        git rev-parse -q --verify HEAD >/dev/null || { cd "$WORK"; continue; }

        if $python; then
            step "just install" just install
            step "just test" just test
            step "just lint ./src" just lint ./src
            step "just check-types" just check-types
            step "just check-docstrings src" just check-docstrings src
            step "just build" just build
            step "just publish-test (dry run)" uv publish --dry-run --index testpypi
            step "tag 0.1.0 builds version 0.1.0" test -f dist/smoke_test-0.1.0-py3-none-any.whl
            step "a commit past the tag reports its dev version" dev_version
        fi
        step "just format leaves the tree untouched" bash -c 'just format && git diff --exit-code'
        if $docs; then
            step "just docs-build" bash -c 'just docs-build && test -s public/r/smoke-test/index.html'
        fi
        step "just changelog" just changelog
        step "workflows pass actionlint" uvx --from 'actionlint-py==1.*' actionlint
        # What CI's jdx/mise-action does: CI=true trusts mise.toml, and an empty
        # global config and data dir install only this project's (non-lazy) tools.
        mkdir -p "$WORK/mise" && : >"$WORK/mise/config.toml"
        step "mise installs the mise.toml tools" env CI=true MISE_GLOBAL_CONFIG_FILE="$WORK/mise/config.toml" \
            MISE_DATA_DIR="$WORK/mise/data" MISE_CACHE_DIR="$WORK/mise/cache" MISE_STATE_DIR="$WORK/mise/state" \
            mise install
        if ! $python && ! $docs; then
            step "just --summary lists no docs or Python recipes" bash -c \
                's="$(just --summary)" && ! echo "$s" | tr " " "\n" | grep -xE "docs-.*|install|lint|test|build|publish.*|clean"'
        fi
        cd "$WORK"
    done

    printf '\n'
    if [ "$fails" -eq 0 ]; then printf '\033[32mall checks passed (%s)\033[0m\n' "$VARIANTS"; else
        printf '\033[31m%s check(s) failed in:%s\033[0m\n' "$fails" "$failed_variants"; exit 1; fi
