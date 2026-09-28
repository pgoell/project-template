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
mise run repo:apply-settings   # optional: merge settings + branch protection
```

## What you get

| File | Does |
|---|---|
| `mise.toml` | tool pins; `install`, `test`, `lint`, `fmt`, `check-commits`, `repo:*` tasks |
| `pyproject.toml` | uv package in `src/`, dev group pytest, ruff, ty |
| `.config/lefthook.yaml` | commit-msg: cog; pre-commit: lint; pre-push: test, commits |
| `cog.toml` | Conventional Commits check |
| `.github/workflows/ci.yml` | Lint, Test, Commits jobs |
| `.github/workflows/pr-title.yml` | PR title must be a conventional commit |
| `.github/dependabot.yml` | weekly uv and Actions updates |
| `.github/*.json`, `scripts/` | repo settings and branch protection, applied with `gh` |
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
