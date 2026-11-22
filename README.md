# project-template

[Copier](https://copier.readthedocs.io) template for a project in the setup I use everywhere: mise, lefthook, cocogitto, and GitHub CI with a Claude review on every pull request. The code can be Python, TypeScript, C++, or none at all (docs, decks).

## Questions

| Question | Choices | Does |
|---|---|---|
| `stack` | `python` (default), `typescript`, `cpp`, `none` | python: uv, ruff, ty, pytest. typescript: bun, biome, tsc, vitest. cpp: CMake, Ninja, clang-format, clang-tidy, GoogleTest, and a Debug build under AddressSanitizer and UndefinedBehaviorSanitizer; the compiler comes from the system. All three share the mise task names. none: no code and no Test job; the review runs after Lint. |
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
mise run repo:apply-settings   # applies the settings in .github/*.json
claude setup-token             # prints an OAuth token for your Claude subscription
gh secret set CLAUDE_CODE_OAUTH_TOKEN   # paste the token
```

Then set up the two files that say how a change is checked here; see "Set up verify and REVIEW.md" below.

Agents push as a separate GitHub account, not as you: invite it as a collaborator with write access, and give it a classic token with the `repo` scope and not the `workflow` scope, so it cannot change `.github/workflows`. A fine-grained token cannot reach a repo of another personal account.

## Set up verify and REVIEW.md

A fresh render checks a change with lint, the tests and the Claude review. Two files make those checks fit the project, and both start as marked sections to fill in.

`.claude/skills/verify/SKILL.md` tells an agent how to run a change in the real app before it commits. Fill it in once the project has something to start:

1. Ask Claude: "Fill in the verify skill. Find how this app starts on dev data, drive one real user flow, and say what to keep as evidence."
2. Ask it to run the skill three times from a clean checkout. All three runs must give the same result in under a minute; fix what makes them differ.
3. Under Drive, list the few flows that must always work. Add a flow when a bug gets past it.
4. Delete the "Not filled in yet" section.

`REVIEW.md` tells the CI reviewer what to look for:

1. "What counts as a failure here": the few ways a change does real harm in this project, one line each.
2. "Security model": who may reach what, and where secrets live.
3. "Checks by trigger" starts empty. Each time a bug gets past review, add a row: what in the diff should have raised the question, what to check, and the pull request it comes from. The reviewer checks only the rows whose trigger a diff matches.

Both files sit under paths in `.github/CODEOWNERS`, so a pull request that changes them waits for a code owner.

## Review and merge

- `Review` and `Security` run `anthropics/claude-code-action` after Lint and Test pass, on pull requests from a branch of this repo that are not drafts and not from Dependabot. They post each Important finding as a thread, which must be answered before the merge, and put Design (at most 3), Pre-existing and Nit findings in a summary. Round 1 reads the whole pull request, later rounds only the new commits. The rounds have no limit.
- The review reads `REVIEW.md` and `.github/review/` from the base branch, so a pull request cannot loosen the review that judges it; a change to them counts from the next pull request on. The workflow file itself still comes from the pull request, which GitHub does for every `pull_request` run; the code owner review guards it.
- A pull request that touches a path in `.github/CODEOWNERS` (CI, settings, scripts, agent settings, deploy and container files, migrations, the manifest and lock) needs a review from a code owner. GitHub reads that file from the base branch, so a pull request cannot take its own paths off the list. A push dismisses the review.
- Branch protection does not bind admins, so the owner merges a risky pull request of their own with `gh pr merge --admin`. Nobody else can.
- `python3 .github/review/outcomes.py [days] [sample size]` counts how the Important threads were answered, the rounds each pull request took, and picks pull requests with Design points for you to read.

## What you get

| File | Does |
|---|---|
| `mise.toml` | tool pins; `install`, `test`, `lint`, `fmt`, `check-commits`, `repo:*` tasks (none has no `test`, `lint` or `fmt`) |
| `pyproject.toml` (python) | uv package in `src/`, dev group pytest, ruff (with complexity limits and no relative imports), ty |
| `package.json`, `tsconfig.json`, `biome.json` (typescript) | bun package in `src/`, strict tsc, biome with a complexity limit, vitest |
| `CMakeLists.txt`, `CMakePresets.json`, `.clang-format`, `.clang-tidy` (cpp) | C++20 library and executable in `src/`, warnings as errors, GoogleTest pinned by hash, `dev` preset with sanitizers, clang-tidy with a complexity limit |
| `.config/lefthook.yaml` | commit-msg: cog; pre-commit: lint, file size, fan-out, comments; pre-push: test, commits, file size, fan-out, comments (none has no lint, test or comments) |
| `cog.toml` | Conventional Commits check |
| `.github/workflows/ci.yml` | Lint (with file size, fan-out and comments), Test, Commits, Review and Security jobs, every action pinned to a commit SHA |
| `.claude/skills/verify/SKILL.md` | how an agent runs a change in the real app before a commit, to fill in |
| `.github/review/`, `REVIEW.md` | the review prompts and scripts, the outcomes report, and what the reviewer looks for |
| `.github/CODEOWNERS` | the risky paths and who must review them |
| `.github/pull_request_template.md` | What and why, Changes, Decisions, Testing, Risk, How to revert |
| `.github/ISSUE_TEMPLATE/task.md` | What and why, Out of scope, Done when |
| `.github/workflows/pr-title.yml` | PR title must be a conventional commit |
| `.github/dependabot.yml` | weekly uv or bun, and Actions updates (cpp: Actions only, since Dependabot does not read CMake) |
| `.github/*.json`, `scripts/` | repo settings, branch protection (code owner reviews), Actions allowlist, required SHA pins, fork PR approval, vulnerability alerts and Dependabot security updates, applied with `gh` |
| `scripts/check-file-size` | fails on any authored file over 5000 tokens (bytes/4); add exclude globs in `.file-size-excludes` |
| `scripts/check-fan-out` | fails on any folder with more than 7 entries; `--all` checks every folder, `--update-baseline` only lowers `.fan-out-baseline`; skip folders in `.fan-out-excludes` |
| `scripts/check-comments` (not none) | fails on a comment that a change adds to Python, TypeScript, JavaScript, C or C++; lets through license headers, tool directives, doc comments and comments that link their source; skip paths in `.comments-excludes`. The [pstack](https://github.com/cursor/plugins/tree/main/pstack) `no-comments` rule, as a check |
| `scripts/structure-hook`, `.claude/settings.json` | Claude Code `PostToolUse` hook: runs the file size and fan-out checks on each edited file; needs `jq` on `PATH` or in mise's global config (`mise use -g jq`) |
| `.claude/CLAUDE.md` | project instructions for Claude Code |

## Update a generated project

```sh
cd my-project
uvx copier update
```

## Develop the template

```sh
mise run test
```

It tests the check scripts, then renders every stack and context into a temp dir and runs lint, tests, actionlint and shellcheck there.

`scripts/check-fan-out`, `check-file-size` and `structure-hook` are copies: their canonical source is `plugins/structure/skills/setting-up-the-checks/assets/` in [pgoell-claude-tools](https://github.com/pgoell/pgoell-claude-tools). `mise run test` fetches that folder from its master and fails when a copy differs or the fetch fails, so it needs the network. Fix a script there first, then copy its bytes here. The `pre-commit` and `pre-push` scripts there stay out: lefthook does their work here.
