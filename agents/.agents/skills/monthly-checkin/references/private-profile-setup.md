# Private profile setup

The reusable skill is safe to keep in a public dotfiles repository. Real company context, employee names, private repo topology, product strategy, incidents, metrics, and submitted check-ins are not.

Store that material outside the skill at:

```text
~/.config/monthly-checkin/
├── config.json
├── profile.md
├── voice.md
└── golden-example.md
```

These files are intentionally not tracked by this repository. Generated evidence and drafts also belong outside the repo, under the `output_dir` configured in `config.json`.

## Bootstrap

```bash
mkdir -p ~/.config/monthly-checkin
chmod 700 ~/.config/monthly-checkin

cp ~/.agents/skills/monthly-checkin/templates/config.example.json \
  ~/.config/monthly-checkin/config.json
cp ~/.agents/skills/monthly-checkin/templates/profile.example.md \
  ~/.config/monthly-checkin/profile.md
cp ~/.agents/skills/monthly-checkin/templates/voice.example.md \
  ~/.config/monthly-checkin/voice.md
cp ~/.agents/skills/monthly-checkin/templates/golden-example.example.md \
  ~/.config/monthly-checkin/golden-example.md

chmod 600 ~/.config/monthly-checkin/*
```

Then replace placeholders with private values.

## Required file contracts

### `config.json`

Machine-readable settings used by the evidence script:

- `person_name`: display name used in evidence headings
- `repo`: local path to the private work repository
- `window_start_day`: first day of the work window
- `window_end_day`: last day of the named month's work window
- `due_day`: day in the following month when the check-in is due
- `output_dir`: private location for evidence and drafts
- `project_paths`: repo-relative paths used to find collaboration candidates

### `profile.md`

Private company and team context:

- how the check-in cadence works;
- issue tracker and project-memory sources;
- team shape and ownership model;
- recurring outcome areas;
- current product direction and growth context;
- valid performance-rating options.

### `voice.md`

Personal writing rules, edited phrases, punctuation preferences, and private examples. Public examples are fine in the template; real company examples stay here.

### `golden-example.md`

The most recent check-in the user actually submitted, or the best edited draft until one is available. Replace it after each submission so the skill follows the user's current voice.

## Public-repo safety check

Before committing skill changes, search the skill directory for private identifiers and inspect the staged diff:

```bash
rg -n -i 'company|internal-project|coworker' \
  ~/.agents/skills/monthly-checkin

git diff --cached -- agents/.agents/skills/monthly-checkin
```

Use identifiers appropriate to your workplace. Do not rely on this example search as a complete secret scanner.

If private material was committed locally but not pushed, amend or rewrite that commit before pushing. A later deletion commit still publishes the original content in history.
