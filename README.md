# project-template

[Copier](https://copier.readthedocs.io) template for a project in the setup I use everywhere: mise, lefthook, cocogitto, and GitHub CI with a Claude review on every pull request. The code can be Python, TypeScript, or none at all (docs, decks).

## Questions

| Question | Choices | Does |
|---|---|---|
| `stack` | `python` (default), `typescript`, `none` | python: uv, ruff, ty, pytest. typescript: bun, biome, tsc, vitest, with the same mise task names. none: no code and no Test job; the review runs after Lint. |
| `context` | `personal` (default), `work` | work leaves out every personal default (author, approver). |
| `approvers` | GitHub logins, space-separated | own the risky paths in `.github/CODEOWNERS`, and their comments reach the reviewer. Defaults to `pgoell` for personal; work must name them. |

Python asks for `package_name`, `python_version`, `author_name` and `author_email` too.

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
claude setup-token             # prints an OAuth token for your Claude subscription
gh secret set CLAUDE_CODE_OAUTH_TOKEN   # paste the token
```

Then fill in the two marked sections of `REVIEW.md`: what counts as a failure in this project, and its security model.

Agents push as a separate GitHub account, not as you: invite it as a collaborator with write access, and give it a classic token with the `repo` scope and not the `workflow` scope, so it cannot change `.github/workflows`. A fine-grained token cannot reach a repo of another personal account.

## Review and merge

- `Review` and `Security` run `anthropics/claude-code-action` after Lint and Test pass, on pull requests from a branch of this repo that are not drafts and not from Dependabot. They post each Important finding as a thread, which must be answered before the merge, and put Design (at most 3), Pre-existing and Nit findings in a summary. Round 1 reads the whole pull request, later rounds only the new commits, and after 3 rounds they stop and ask for a rethink.
- A pull request that touches a path in `.github/CODEOWNERS` (CI, settings, scripts, agent settings, deploy and container files, migrations, the manifest and lock) needs a review from a code owner. GitHub reads that file from the base branch, so a pull request cannot take its own paths off the list. A push dismisses the review.
- Branch protection does not bind admins, so the owner merges a risky pull request of their own with `gh pr merge --admin`. Nobody else can.
- `python3 .github/review/outcomes.py [days] [sample size]` counts how the Important threads were answered, the rounds each pull request took, and picks pull requests with Design points for you to read.

## What you get

| File | Does |
|---|---|
| `mise.toml` | tool pins; `install`, `test`, `lint`, `fmt`, `check-commits`, `repo:*` tasks (none has no `test`, `lint` or `fmt`) |
| `pyproject.toml` (python) | uv package in `src/`, dev group pytest, ruff (with complexity limits and no relative imports), ty |
| `package.json`, `tsconfig.json`, `biome.json` (typescript) | bun package in `src/`, strict tsc, biome with a complexity limit, vitest |
| `.config/lefthook.yaml` | commit-msg: cog; pre-commit: lint, file size, fan-out; pre-push: test, commits, file size, fan-out |
| `cog.toml` | Conventional Commits check |
| `.github/workflows/ci.yml` | Lint (with file size and fan-out), Test, Commits, Review and Security jobs, every action pinned to a commit SHA |
| `.github/review/`, `REVIEW.md` | the review prompts, the round counter, the reviewer's context, the outcomes report, and what the reviewer looks for |
| `.github/CODEOWNERS` | the risky paths and who must review them |
| `.github/pull_request_template.md` | What and why, Testing, Risk, How to revert |
| `.github/workflows/pr-title.yml` | PR title must be a conventional commit |
| `.github/dependabot.yml` | weekly uv or bun, and Actions updates |
| `.github/*.json`, `scripts/` | repo settings, branch protection (code owner reviews), Actions allowlist, required SHA pins, fork PR approval, vulnerability alerts and Dependabot security updates, applied with `gh` |
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
mise run test   # renders every stack and context into a temp dir, then runs lint, tests, actionlint and shellcheck there
```
