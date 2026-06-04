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
- GitHub Actions workflows (test, Dependabot, auto-merge, release)
- VSCode settings
- GitHub repository creation and branch protection rules

### init-typescript-project

Automates the initial setup of a TypeScript project.

### setup-ruby-hooks

Installs Claude Code hooks tailored for Ruby projects (rbs-inline, pre-commit checks, sig protection, etc.).

### setup-dev-workflow-hooks

Installs Claude Code hooks for general development workflow (self-review, etc.).

### setup-github-workflows

Sets up language-agnostic GitHub Actions workflows (workflow-lint, auto-merge, Dependabot auto-label), a base Dependabot config, and branch protection for a repository. Run once on an existing repository whose default branch is not yet protected.
