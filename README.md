# skills

A repository of [agent skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills) installable via `gh skill`.

## About

Each skill lives under `skills/<skill-name>/` with a `SKILL.md` and any supporting files. The skills are designed primarily for [Claude Code](https://claude.ai/claude-code), but the layout follows the standard agent skill spec.

## Installation

Install a skill at user scope (available across all projects):

```
gh skill install tk0miya/skills <skill-name> --agent claude-code --scope user
```

Or at project scope (writes into the current repo's `.claude/skills/`):

```
gh skill install tk0miya/skills <skill-name> --agent claude-code --scope project
```

## Skills

### init-ruby-project

Automates the initial setup of a Ruby project.

Run it in the project directory. Sets up the following automatically:

- Gemfile (and gemspec for a gem)
- RuboCop / Steep configuration files
- Ruby-specific GitHub Actions workflows (CI, rbs_collection, release) and Dependabot config (bundler)
- Claude Code hooks tailored for Ruby (rbs-inline, pre-commit checks, sig protection)
- VSCode settings
- GitHub repository creation

It inspects the current directory and skips whatever is already done, so it also works on a
project that is partly set up. It does not scaffold: run `bundle gem` yourself first for a gem.

Delegates the language-agnostic GitHub setup to `setup-github-workflows` and the general
development workflow hooks to `setup-dev-workflow-hooks`, both of which must also be installed.

### init-typescript-project

Automates the initial setup of a TypeScript project.

Sets up the following automatically:

- Scaffolding, tsconfig / Biome / Vitest configuration files
- TypeScript-specific GitHub Actions workflows (CI, biome-migrate) and Dependabot config (npm)
- Claude Code hooks tailored for TypeScript (pre-commit checks)
- VSCode settings
- GitHub repository creation

Delegates the language-agnostic GitHub setup to `setup-github-workflows` and the general
development workflow hooks to `setup-dev-workflow-hooks`, both of which must also be installed.

### setup-dev-workflow-hooks

Installs Claude Code hooks for general development workflow (self-review, etc.). The
self-review hook holds back the first commit of a change-set until the changes have been
reviewed, and stops gating once the same commit has been reviewed five times, so a review
that keeps finding something to fix cannot block the commit forever.

### self-review

Single source of truth for code-review perspectives. Just before committing, it self-reviews the changes about to be committed against a common checklist plus perspectives selected from the project's stack and the files being changed (e.g. RSpec for Ruby, or CLAUDE.md), loaded additively. Findings come back graded: a defect carries one sentence on what breaks if it is left, and a judgement call — a choice with no basis in the repository — carries the options instead of a verdict, both tagged with the perspective they came from. A point that is neither is not reported at all. The caller weighs that grading to decide what to act on, settles a judgement call rather than fixing it, and says out loud what it skips. Along with the findings it hands back a command that appends them to `.git/self-review-log.jsonl`, one JSON object per line, so past findings can be read back later. The log is local to the clone and never committed. Add a perspective by dropping a `references/<name>.md` into the skill and adding a row to the selection table in its `SKILL.md`.

### setup-github-workflows

Sets up language-agnostic GitHub Actions workflows (workflow-lint, auto-merge, Dependabot auto-label), the `github-actions` Dependabot update config (merged into an existing `dependabot.yml` if present), branch protection, and the project-wide GitHub App credentials for a repository. Run it once per repository, right after creating and pushing it.

This is the single source of truth for that setup: the `init-*` skills delegate to it rather than setting it up themselves. Each side registers its own status checks into the same `main` ruleset, which is created by whichever call reaches it first.
