# {{WIKI_NAME}} — Schema

> Domain: {{DOMAIN}}
> Created: {{DATE}}

This file defines the conventions and workflows for this wiki. The LLM reads this before every operation to maintain consistency.

## Wiki Structure

```
{{WIKI_NAME}}/
├── raw/                    # Source documents (immutable)
│   └── assets/             # Downloaded images and attachments
├── wiki/                   # LLM-maintained knowledge pages
│   ├── index.md            # Content catalog by category
│   ├── log.md              # Chronological activity record
│   ├── sources/            # Source summary pages
│   ├── entities/           # Entity pages (people, orgs, tools)
│   ├── concepts/           # Concept and theme pages
│   └── synthesis/          # Cross-cutting analysis and comparisons
└── SCHEMA.md               # This file
```

## Conventions

### Page Naming
- Use kebab-case: `machine-learning.md`, `andrej-karpathy.md`
- Source summaries mirror the source filename: `raw/paper.pdf` → `wiki/sources/paper.md`
- No spaces in filenames

### Frontmatter
Every wiki page MUST have YAML frontmatter:
```yaml
---
title: "Page Title"
type: source | entity | concept | synthesis
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources:
  - raw/filename1
  - raw/filename2
tags:
  - tag1
  - tag2
---
```

### Cross-References
- Use `[[wikilinks]]` for all internal references (Obsidian-compatible)
- When mentioning an entity or concept that has its own page, always link it
- When creating a new page, add links from existing related pages

### Writing Style
- Be concise and factual
- Lead with the most important information
- Use bullet points for lists of facts
- Use tables for comparisons
- Note contradictions explicitly: "Source A claims X, but Source B claims Y"
- Include dates when they matter

## Workflows

### On Ingest
1. Read this schema
2. Read `wiki/index.md`
3. Read the source document
4. Discuss key findings with the user
5. Create source summary in `wiki/sources/`
6. Create or update entity pages in `wiki/entities/`
7. Create or update concept pages in `wiki/concepts/`
8. Update synthesis pages if applicable
9. Update `wiki/index.md`
10. Append to `wiki/log.md`

### On Query
1. Read this schema
2. Read `wiki/index.md` to find relevant pages
3. Read relevant pages
4. Synthesize answer with `[[citations]]`
5. Optionally file answer as new synthesis page

### On Lint
1. Read all wiki pages
2. Check for: contradictions, orphans, stale claims, missing links, concept gaps
3. Report findings with priorities
4. Fix with user approval

## Domain-Specific Notes

{{DOMAIN_NOTES}}
