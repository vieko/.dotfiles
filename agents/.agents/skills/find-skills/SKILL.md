---
name: find-skills
description: Discover and install agent skills from the open ecosystem (skills.sh) when the user asks for a skill, wants to extend agent capabilities, or asks for functionality that might exist as an installable skill.
---

# Find Skills

`npx skills` is the package manager for the open agent skills ecosystem.
Browse at https://skills.sh/.

```bash
npx skills find [query]            # search (interactive without a query)
npx skills add <owner/repo@skill>  # install; -g = user-level, -y = skip prompts
npx skills check                   # check for updates
npx skills update                  # update all installed skills
npx skills init <name>             # scaffold a new skill
```

Search with specific keywords ("react testing", not "testing"). Present
matches with the install command and the skills.sh link; install with
`-g -y` when the user wants it. If nothing matches, help with the task
directly and mention `npx skills init` if it's something they do often.
