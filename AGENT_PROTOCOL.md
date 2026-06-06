# Agent Editing Protocol

## How AI Agents Should Edit Content

This document defines the safe, repeatable workflow for AI agents (like OpenCode/Kimi) to edit site content.

## 1. Content Location

All editable content lives in `site/content/`:

```
site/content/
├── _index.md                 # Homepage content (hero text, CTAs)
├── la-parroquia/_index.md    # Section landing pages
├── celebraciones/_index.md
├── catequesis/_index.md
├── horarios/_index.md        # Individual pages
├── contactar/_index.md
└── posts/                     # Blog posts
    └── yyyy-mm-dd-slug.md
```

## 2. File Naming Convention

### Pages (sections)
- Use `_index.md` for section landing pages
- Directory name = URL slug
- Examples: `la-parroquia/_index.md`, `catequesis/infantiles/_index.md`

### Posts (blog/news)
- Format: `YYYY-MM-DD-{descriptive-slug}.md`
- Examples: `2025-01-15-nuevo-horario.md`
- Place in `site/content/posts/`

## 3. Required Front Matter

Every Markdown file MUST start with:

```yaml
---
title: "Descriptive Title"
date: 2025-01-15T10:00:00+01:00
lastmod: 2025-01-15T10:00:00+01:00
---
```

Optional fields:
- `description: "Short summary for SEO and listings"`
- `draft: true` — to hide from build

## 4. Image Handling Rules

### Where to put images
- New images: `site/static/images/{section}/{filename}`
- Existing WordPress images: `site/static/images/wp-content/...` (auto-migrated)

### How to reference images
Use root-relative paths:
```markdown
![Alt text describing the image](/images/la-parroquia/altar.jpg)
```

### Image requirements
- Prefer WebP or optimized JPEG
- Max width: 1200px for content images
- Always include descriptive `alt` text
- No inline `style` attributes

## 5. Safety Check Before Commit

After ANY content edit, the agent MUST:

```bash
# 1. Build the site locally
cd site && hugo --minify

# 2. Verify no build errors
# Expected output: "Total in XX ms" with 0 errors

# 3. Check that new pages exist
ls public/{new-page}/index.html

# 4. Only then commit
```

If `hugo --minify` fails:
- DO NOT commit
- Fix the error (usually invalid Markdown or front matter YAML)
- Re-run the build check

## 6. Prohibited Actions

- NEVER edit files outside `site/content/` and `site/static/images/`
- NEVER modify `hugo.toml`, layouts, or CSS without explicit permission
- NEVER commit without running `hugo --minify` first
- NEVER use inline HTML unless absolutely necessary (use Markdown)
- NEVER delete archived WordPress files in `archive/legacy-wordpress/`

## 7. UX Improvement Guidelines

When editing or creating content:

- **Typography:** Use proper heading hierarchy (`#` for page title, `##` for sections, `###` for subsections)
- **Spacing:** Separate sections with blank lines; avoid walls of text
- **Navigation:** Ensure new pages are reachable from existing menus (update `hugo.toml` menu section if adding top-level pages)
- **Mobile:** Keep tables simple; they auto-scroll on mobile via CSS
- **Load performance:** Optimize images before adding; use Hugo image processing for heavy galleries
- **Accessibility:** Always add `alt` text; use descriptive link text (not "click here")

## 8. Code Quality Checklist

For any structural or template changes:

- [ ] Semantic HTML (`<header>`, `<main>`, `<article>`, `<footer>`)
- [ ] ARIA labels on navigation and interactive elements
- [ ] No inline styles — use CSS classes
- [ ] Color contrast meets WCAG AA
- [ ] Keyboard-navigable interactive elements
- [ ] Valid Hugo template syntax
