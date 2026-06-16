---
name: llm-wiki
description: Build and maintain a personal knowledge base using the LLM Wiki pattern (Karpathy). Incrementally ingest sources, query the wiki, and lint for consistency. Use when the user wants to create a knowledge base, ingest documents, query accumulated knowledge, or maintain a personal wiki.
---

# LLM Wiki Skill

A pattern for building personal knowledge bases where the LLM incrementally builds and maintains a persistent wiki — a structured, interlinked collection of markdown files — rather than re-deriving answers from raw sources on every query.

The wiki is a **persistent, compounding artifact**. Cross-references are already there. Contradictions have already been flagged. The synthesis already reflects everything ingested. The wiki keeps getting richer with every source added and every question asked.

## Architecture

Three layers:

```
wiki-root/
├── raw/              # Immutable source documents (articles, papers, notes, data)
│   └── assets/       # Downloaded images and attachments
├── wiki/             # LLM-maintained markdown pages (the knowledge base)
│   ├── index.md      # Content catalog organized by category
│   └── log.md        # Append-only chronological record
└── SCHEMA.md         # Wiki conventions, structure rules, domain config
```

**Raw sources** — curated source documents. Articles, papers, images, data files. Immutable — read from but never modified. This is the source of truth.

**The wiki** — LLM-generated markdown files. Summaries, entity pages, concept pages, comparisons, synthesis. The LLM owns this layer entirely. It creates pages, updates them when new sources arrive, maintains cross-references, and keeps everything consistent.

**The schema** — configuration that tells the LLM how the wiki is structured, what conventions to follow, and what workflows to use. Co-evolved over time as you figure out what works for your domain.

## Operations

### 1. Init

Initialize a new wiki. Create the directory structure, `index.md`, `log.md`, and a starter `SCHEMA.md`.

**Steps:**
1. Ask the user for a wiki name and topic/domain (e.g., "AI Research", "Personal Health", "Book: Lord of the Rings")
2. Ask where to create it (default: current directory)
3. Create the directory structure:
   ```
   <wiki-name>/
   ├── raw/
   │   └── assets/
   ├── wiki/
   │   ├── index.md
   │   └── log.md
   └── SCHEMA.md
   ```
4. Populate `index.md` with an empty category structure appropriate to the domain
5. Populate `log.md` with the creation entry
6. Generate `SCHEMA.md` from the template at `${CLAUDE_SKILL_DIR}/references/schema-template.md`, customized for the domain
7. Initialize git if not already in a repo

### 2. Ingest

Process a new source into the wiki. This is the core operation.

**Steps:**
1. Read the source document from `raw/`
2. Read `SCHEMA.md` to understand wiki conventions
3. Read `wiki/index.md` to understand existing pages
4. Discuss key takeaways with the user
5. Create or update wiki pages:
   - Write a **summary page** for the source in `wiki/sources/`
   - Update **entity pages** — people, organizations, tools, etc.
   - Update **concept pages** — themes, ideas, frameworks
   - Update **comparison/synthesis pages** if the source adds to ongoing analysis
   - Note where new data **contradicts** existing claims
6. Update `wiki/index.md` with new/changed pages
7. Append an entry to `wiki/log.md`

**Important conventions:**
- Use `[[wikilinks]]` for internal cross-references (Obsidian-compatible)
- Add YAML frontmatter to every page: `title`, `type` (source, entity, concept, synthesis), `created`, `updated`, `sources` (list of source filenames)
- A single source typically touches 10-15 wiki pages
- Prefer updating existing pages over creating new ones when the topic overlaps

### 3. Query

Answer questions using the wiki as the knowledge base.

**Steps:**
1. Read `wiki/index.md` to find relevant pages
2. Read the relevant wiki pages
3. Synthesize an answer with citations to specific wiki pages
4. If the answer produces a valuable new synthesis or comparison:
   - Ask the user if it should be filed as a new wiki page
   - If yes, create the page and update `index.md` and `log.md`

**Output formats** (choose based on question type):
- Markdown page (default)
- Comparison table
- Timeline
- Summary with citations

### 4. Lint

Health-check the wiki for quality and consistency.

**Check for:**
- Contradictions between pages
- Stale claims superseded by newer sources
- Orphan pages with no inbound `[[wikilinks]]`
- Important concepts mentioned but lacking their own page
- Missing cross-references between related pages
- Data gaps that could be filled with additional sources
- Pages with outdated frontmatter

**Steps:**
1. Read all wiki pages (or a subset if the wiki is large)
2. Build a map of all `[[wikilinks]]` — which pages link to which
3. Identify issues from the checklist above
4. Present findings to the user as a prioritized list
5. Fix issues with user approval
6. Append a lint entry to `wiki/log.md`

## Page Templates

### Source Summary Page

```markdown
---
title: "<Source Title>"
type: source
created: YYYY-MM-DD
source_file: "raw/<filename>"
---

# <Source Title>

**Author:** ...
**Date:** ...
**Source:** ...

## Key Takeaways

- ...

## Detailed Notes

...

## Connections

- Related to [[existing-page]] because ...
- Contradicts/supports [[other-page]] on ...
```

### Entity Page

```markdown
---
title: "<Entity Name>"
type: entity
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources:
  - raw/source1.md
  - raw/source2.md
---

# <Entity Name>

Brief description.

## Key Facts

- ...

## Appearances in Sources

- In [[source-summary-1]]: ...
- In [[source-summary-2]]: ...

## Related

- [[related-entity]]
- [[related-concept]]
```

### Concept Page

```markdown
---
title: "<Concept>"
type: concept
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources:
  - raw/source1.md
---

# <Concept>

Definition and explanation.

## Key Aspects

- ...

## Evolution Across Sources

| Source | Date | Position |
|--------|------|----------|
| [[source-1]] | ... | ... |

## Related Concepts

- [[related-concept]]
```

## Index Format

```markdown
# Wiki Index

> Last updated: YYYY-MM-DD | Pages: N | Sources: N

## Sources
- [[source-name]] — one-line summary

## Entities
- [[entity-name]] — one-line summary

## Concepts
- [[concept-name]] — one-line summary

## Synthesis
- [[synthesis-name]] — one-line summary
```

## Log Format

```markdown
# Wiki Log

## [YYYY-MM-DD] init | Wiki Created
Wiki initialized for "<domain>".

## [YYYY-MM-DD] ingest | <Source Title>
Processed <source file>. Created: <new pages>. Updated: <existing pages>.

## [YYYY-MM-DD] query | <Question Summary>
Answered question about <topic>. Filed as [[new-page]] (if applicable).

## [YYYY-MM-DD] lint | Health Check
Found N issues. Fixed: <list>. Flagged: <list>.
```

## Tips

- **Obsidian** works great as a viewer — open the wiki directory as a vault, use graph view to see connections
- Use `grep "^## \[" wiki/log.md | tail -10` to see recent activity
- The wiki is just markdown files — version it with git for free history
- At small scale (<100 sources), `index.md` is sufficient for navigation
- For larger wikis, consider adding search tooling like [qmd](https://github.com/tobi/qmd)
- Sources can be anything: articles, papers, book chapters, podcast transcripts, meeting notes, journal entries

## Attribution

Based on the [LLM Wiki pattern by Andrej Karpathy](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
