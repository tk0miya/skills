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

Sets up the following automatically:

- Scaffolding for a gem or a plain Ruby project
- RuboCop / Steep configuration files
- Ruby-specific GitHub Actions workflows (CI, rbs_collection, release) and Dependabot config (bundler)
- VSCode settings
- GitHub repository creation

Delegates the language-agnostic GitHub setup to `setup-github-workflows`, which must also be
installed.

### init-typescript-project

Automates the initial setup of a TypeScript project.

Sets up the following automatically:

- Scaffolding, tsconfig / Biome / Vitest configuration files
- TypeScript-specific GitHub Actions workflows (CI, biome-migrate) and Dependabot config (npm)
- VSCode settings
- GitHub repository creation

Delegates the language-agnostic GitHub setup to `setup-github-workflows`, which must also be
installed.

### setup-ruby-hooks

Installs Claude Code hooks tailored for Ruby projects (rbs-inline, pre-commit checks, sig protection, etc.).

### setup-dev-workflow-hooks

Installs Claude Code hooks for general development workflow (self-review, etc.).

### self-review

Single source of truth for code-review perspectives. Just before committing, it self-reviews the changes about to be committed against a common checklist plus language/framework-specific perspectives (e.g. RSpec for Ruby), loaded additively based on the detected stack, and loops on fixes until the review passes. Add a language/framework by dropping a `references/<name>.md` into the skill.

### setup-github-workflows

Sets up language-agnostic GitHub Actions workflows (workflow-lint, auto-merge, Dependabot auto-label), the `github-actions` Dependabot update config (merged into an existing `dependabot.yml` if present), branch protection, and the project-wide GitHub App credentials for a repository. Run it once per repository, right after creating and pushing it.

This is the single source of truth for that setup: the `init-*` skills delegate to it rather than setting it up themselves. Each side registers its own status checks into the same `main` ruleset, which is created by whichever call reaches it first.
