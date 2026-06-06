#!/usr/bin/env python3
"""Regenerate Hugo content from the WordPress instance currently on localhost."""

import html
import json
import re
import shutil
import urllib.request
from pathlib import Path
from urllib.parse import unquote, urlparse

import html2text

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "site/content"
IMAGES = ROOT / "site/static/images/wp-content"
PAGES_JSON = Path("/tmp/wp-current-pages.json")
POSTS_JSON = Path("/tmp/wp-current-posts.json")
CATEGORIES_JSON = Path("/tmp/wp-current-categories.json")
POSTS_TAX_JSON = Path("/tmp/wp-current-posts-tax.json")
LINK_MAP = {}

FALLBACK_TITLES = {
    "formacion": "Formación",
    "inicio": "Inicio",
    "noticias-de-la-parroquia-2": "Noticias",
    "horarios": "Horarios",
    "seminario-sentido-religioso": "Seminario sobre el Sentido Religioso",
    "jovenes-confirmacion": "Jóvenes y Confirmación",
    "juveniles-post-comunion": "Juveniles y Post Comunión",
    "celebraciones": "Celebraciones",
}


def yaml_quote(value):
    return json.dumps(html.unescape(value), ensure_ascii=False)


def clean_html(value):
    value = re.sub(r"<(?:style|script)\b[^>]*>.*?</(?:style|script)>", "", value, flags=re.I | re.S)
    value = value.replace("http://localhost:8080/wp-content/uploads/", "/images/wp-content/")
    value = value.replace("http://localhost:8080/", "/")
    value = value.replace("http://localhost:8080", "/")
    for old_path, canonical_path in LINK_MAP.items():
        value = re.sub(
            rf'(["\'])/{re.escape(old_path)}/?(["\'])',
            rf'\1/{canonical_path}/\2',
            value,
        )
    return value


def to_markdown(value):
    converter = html2text.HTML2Text()
    converter.body_width = 0
    converter.ignore_images = False
    converter.ignore_links = False
    converter.ignore_tables = False
    converter.wrap_links = False
    converter.wrap_list_items = False
    result = converter.handle(clean_html(value))
    result = re.sub(r"\n{3,}", "\n\n", result)
    return "\n".join(line.rstrip() for line in result.strip().splitlines())


def wordpress_path(link):
    path = urlparse(link).path.strip("/")
    return unquote(path)


def write_record(record, is_post=False):
    slug = record["slug"]
    path = wordpress_path(record["link"])
    if not path or slug == "inicio":
        return

    title = html.unescape(record["title"]["rendered"]).strip() or FALLBACK_TITLES.get(slug, slug.replace("-", " ").title())
    body = to_markdown(record["content"]["rendered"])
    description = html.unescape(re.sub(r"<[^>]+>", " ", record.get("excerpt", {}).get("rendered", "")))
    description = re.sub(r"\s+", " ", description).strip()

    target = CONTENT / path / "_index.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    frontmatter = [
        "---",
        f"title: {yaml_quote(title)}",
        f"date: {yaml_quote(record.get('date') or record.get('modified'))}",
        f"lastmod: {yaml_quote(record['modified'])}",
        f"url: {yaml_quote('/' + path + '/')}",
        "source: \"wordpress-localhost\"",
        f"show_title: {'true' if wordpress_displays_title(record['link']) else 'false'}",
    ]
    if description:
        frontmatter.append(f"description: {yaml_quote(description[:240])}")
    frontmatter.extend(["---", "", body, ""])
    target.write_text("\n".join(frontmatter), encoding="utf-8")


def wordpress_displays_title(link):
    with urllib.request.urlopen(link) as response:
        rendered = response.read().decode("utf-8", errors="ignore")
    return "wp-block-post-title" in rendered


def write_category(category, posts_by_category):
    path = wordpress_path(category["link"])
    target = CONTENT / path / "_index.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "---",
        f"title: {yaml_quote(category['name'])}",
        f"url: {yaml_quote('/' + path + '/')}",
        "source: \"wordpress-localhost\"",
        "show_title: true",
        "---",
        "",
    ]
    if category.get("description"):
        lines.extend([to_markdown(category["description"]), ""])
    for post in posts_by_category.get(category["id"], []):
        lines.append(f"- [{html.unescape(post['title']['rendered'])}]({urlparse(post['link']).path})")
    lines.append("")
    target.write_text("\n".join(lines), encoding="utf-8")


def referenced_media(records):
    urls = set()
    pattern = re.compile(r"http://localhost:8080/wp-content/uploads/[^\"'\s<>)]+")
    for record in records:
        urls.update(pattern.findall(record["content"]["rendered"]))
    return sorted(urls)


def download_media(url):
    relative = url.split("/wp-content/uploads/", 1)[1]
    target = IMAGES / relative
    if target.exists():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, target)


def main():
    global LINK_MAP
    pages = json.loads(PAGES_JSON.read_text(encoding="utf-8"))
    posts = json.loads(POSTS_JSON.read_text(encoding="utf-8"))
    categories = json.loads(CATEGORIES_JSON.read_text(encoding="utf-8"))
    posts_tax = json.loads(POSTS_TAX_JSON.read_text(encoding="utf-8"))
    LINK_MAP = {
        record["slug"]: wordpress_path(record["link"])
        for record in pages + posts
        if wordpress_path(record["link"])
    }

    if CONTENT.exists():
        shutil.rmtree(CONTENT)
    CONTENT.mkdir(parents=True)

    for page in pages:
        write_record(page)
    for post in posts:
        write_record(post, is_post=True)
    posts_by_category = {}
    for post in posts_tax:
        for category_id in post["categories"]:
            posts_by_category.setdefault(category_id, []).append(post)
    for category in categories:
        write_category(category, posts_by_category)
    for url in referenced_media(pages + posts):
        download_media(url)

    print(f"Generated {len(pages) - 1} pages and {len(posts)} posts from localhost WordPress.")


if __name__ == "__main__":
    main()
