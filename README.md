# project-template

[Copier](https://copier.readthedocs.io) template for a Python project in the setup I use everywhere: mise, uv, lefthook, cocogitto, ruff, ty, pytest, and GitHub CI.

## New project

```sh
cd ~/Code
uvx copier copy gh:pgoell/project-template my-project
cd my-project
git init -b master
mise trust && mise install && mise run install
git add -A && git commit -m "chore: initial commit"
gh repo create pgoell/my-project --public --source . --push
mise run repo:apply-settings   # merge settings, branch protection, Actions allowlist and SHA pinning, Dependabot security updates
```

## What you get

| File | Does |
|---|---|
| `mise.toml` | tool pins; `install`, `test`, `lint`, `fmt`, `check-commits`, `repo:*` tasks |
| `pyproject.toml` | uv package in `src/`, dev group pytest, ruff (with complexity limits and no relative imports), ty |
| `.config/lefthook.yaml` | commit-msg: cog; pre-commit: lint, file size, fan-out; pre-push: test, commits, file size, fan-out |
| `cog.toml` | Conventional Commits check |
| `.github/workflows/ci.yml` | Lint (with file size and fan-out), Test, Commits jobs, every action pinned to a commit SHA |
| `.github/workflows/pr-title.yml` | PR title must be a conventional commit |
| `.github/dependabot.yml` | weekly uv and Actions updates |
| `.github/*.json`, `scripts/` | repo settings, branch protection (admins included), Actions allowlist, required SHA pins, fork PR approval, vulnerability alerts and Dependabot security updates, applied with `gh` |
| `scripts/check-file-size` | fails on any authored file over 5000 tokens (bytes/4); add exclude globs in `.file-size-excludes` |
| `scripts/check-fan-out` | fails on any folder with more than 7 entries; `--all` checks every folder, `--update-baseline` only lowers `.fan-out-baseline`; skip folders in `.fan-out-excludes` |
| `scripts/structure-hook`, `.claude/settings.json` | Claude Code `PostToolUse` hook: runs both checks on each edited file |
| `.claude/CLAUDE.md` | project instructions for Claude Code |

## Update a generated project

```sh
cd my-project
uvx copier update
```

## Develop the template

```sh
mise run test   # renders into a temp dir, then runs lint and tests there
```
