#!/usr/bin/env python3
"""
WordPress SQL Dump → Hugo Markdown Migration Script

Usage:
    cd /home/juan/church_website
    python3 migration/scripts/wordpress_to_hugo.py

Requirements:
    - python3, html2text
    - Access to dumps/*.sql and wp-content/uploads/

Output:
    - site/content/pages/*.md
    - site/content/posts/*.md
    - site/static/images/wp-content/...
    - migration/redirects.caddy
"""

import re
import os
import sys
import shutil
import html2text
from pathlib import Path
from collections import defaultdict

# Configuration
PROJECT_ROOT = Path(__file__).resolve().parents[2]
SQL_FILE = PROJECT_ROOT / "dumps" / "live-20260426-011104.sql"
UPLOADS_DIR = PROJECT_ROOT / "wp-content" / "uploads"
OUTPUT_PAGES = PROJECT_ROOT / "site" / "content"
OUTPUT_POSTS = PROJECT_ROOT / "site" / "content" / "posts"
OUTPUT_IMAGES = PROJECT_ROOT / "site" / "static" / "images" / "wp-content"
REDIRECTS_FILE = PROJECT_ROOT / "migration" / "redirects.caddy"

# Ensure output dirs exist
OUTPUT_PAGES.mkdir(parents=True, exist_ok=True)
OUTPUT_POSTS.mkdir(parents=True, exist_ok=True)
OUTPUT_IMAGES.mkdir(parents=True, exist_ok=True)


def parse_sql_rows(content, table_name, field_names):
    """Extract rows from INSERT INTO `table` (...) VALUES (...); lines."""
    field_list = ','.join(f'`{f}`' for f in field_names)
    prefix = f"INSERT INTO `{table_name}` ({field_list}) VALUES "
    
    rows = []
    for line in content.split('\n'):
        if not line.startswith(prefix):
            continue
        
        # Extract the values part: everything after VALUES until the final );
        values_start = line.find('VALUES ') + len('VALUES ')
        values_str = line[values_start:]
        
        # Each INSERT line ends with );
        if not values_str.endswith(');'):
            continue
        values_str = values_str[:-2]  # strip trailing );
        
        # Each row is wrapped in (...). Since each INSERT line has one row,
        # we just verify it starts with ( and then strip it.
        if not values_str.startswith('('):
            continue
        row_inner = values_str[1:]  # strip leading (
        
        # Split fields respecting single quotes and backslash escapes
        fields = []
        current = []
        in_quotes = False
        escape_next = False
        
        i = 0
        while i < len(row_inner):
            if escape_next:
                current.append(row_inner[i])
                escape_next = False
                i += 1
                continue
            c = row_inner[i]
            if c == "\\":
                current.append(c)
                escape_next = True
                i += 1
                continue
            if c == "'":
                in_quotes = not in_quotes
                current.append(c)
                i += 1
                continue
            if c == ',' and not in_quotes:
                fields.append(''.join(current).strip())
                current = []
                i += 1
                continue
            current.append(c)
            i += 1
        if current:
            fields.append(''.join(current).strip())
        
        if len(fields) >= len(field_names):
            row_dict = {}
            for idx, fname in enumerate(field_names):
                val = fields[idx].strip().strip("'")
                val = val.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n").replace("\\r", "\r")
                row_dict[fname] = val
            rows.append(row_dict)
    return rows


def html_to_markdown(html):
    """Convert WordPress HTML content to clean Markdown."""
    if not html or not html.strip():
        return ""
    
    h = html2text.HTML2Text()
    h.body_width = 0
    h.wrap_links = False
    h.wrap_list_items = False
    h.use_automatic_links = True
    h.ignore_images = False
    h.ignore_links = False
    h.ignore_tables = False
    h.mark_code = True
    h.escape_snob = True
    
    md = h.handle(html)
    md = re.sub(r'\n{3,}', '\n\n', md)
    md = md.strip()
    
    return md


def clean_slug(post_name):
    """Ensure slug is URL-safe."""
    slug = post_name.lower().strip()
    slug = re.sub(r'[^a-z0-9\-_]', '-', slug)
    slug = re.sub(r'-+', '-', slug)
    slug = slug.strip('-')
    return slug or "untitled"


SLUG_MAP = {
    'inicio': ('_index.md', ''),
    'parroquia': ('la-parroquia.md', 'la-parroquia'),
    'la-parroquia': ('la-parroquia.md', 'la-parroquia'),
    'como-llegar': ('como-llegar.md', 'la-parroquia/como-llegar'),
    'nuestra-historia': ('historia.md', 'la-parroquia/historia'),
    'historia': ('historia.md', 'la-parroquia/historia'),
    'nuestro-patrono': ('san-pablo.md', 'la-parroquia/san-pablo'),
    'san-pablo-de-la-cruz': ('san-pablo.md', 'la-parroquia/san-pablo'),
    'galeria-fotografica': ('galeria.md', 'la-parroquia/galeria'),
    'haciendo-camino': ('haciendo-camino.md', 'la-parroquia/haciendo-camino'),
    'tablon-de-avisos': ('avisos.md', 'la-parroquia/avisos'),
    'contactar': ('contactar.md', 'contactar'),
    'celebraciones': ('celebraciones.md', 'celebraciones'),
    'tiempos-liturgicos': ('liturgia.md', 'celebraciones/liturgia'),
    'liturgia': ('liturgia.md', 'celebraciones/liturgia'),
    'bautismos': ('bautismos.md', 'celebraciones/bautismos'),
    'matrimonios': ('matrimonios.md', 'celebraciones/matrimonios'),
    'formacion': ('catequesis.md', 'catequesis'),
    'catequesis': ('catequesis.md', 'catequesis'),
    'infantiles-primera-comunion': ('infantiles.md', 'catequesis/infantiles'),
    'juveniles-post-comunion': ('juveniles.md', 'catequesis/juveniles'),
    'jovenes-confirmacion': ('jovenes.md', 'catequesis/jovenes'),
    'universitarios-universidad': ('universitarios.md', 'catequesis/universitarios'),
    'universitarios': ('universitarios.md', 'catequesis/universitarios'),
    'familia-escuela-de-padres': ('familia.md', 'catequesis/familia'),
    'escuela-de-cristianismo': ('escuela-cristianismo.md', 'catequesis/escuela-cristianismo'),
    'seminario-sentido-religioso': ('seminario.md', 'catequesis/seminario'),
    'inscripcion': ('inscripcion.md', 'catequesis/inscripcion'),
    'horarios': ('horarios.md', 'horarios'),
    'politica-de-cookies': ('politica-cookies.md', 'politica-de-cookies'),
    'dialogo-con-maria-san-gil': ('dialogo-maria-san-gil.md', 'dialogo-maria-san-gil'),
    'galeria-de-eventos': ('galeria-eventos.md', 'galeria-eventos'),
    'noticias-de-la-parroquia-2': ('noticias.md', 'noticias'),
}


def determine_section(page, all_pages_by_id):
    """Map WordPress pages to Hugo content structure."""
    slug = clean_slug(page['post_name'])
    parent_id = page.get('post_parent', '0')
    
    if slug in SLUG_MAP:
        return SLUG_MAP[slug]
    
    if parent_id != '0' and parent_id in all_pages_by_id:
        parent = all_pages_by_id[parent_id]
        parent_slug = clean_slug(parent['post_name'])
        if parent_slug == 'parroquia':
            return (f"{slug}.md", f"la-parroquia/{slug}")
        elif parent_slug == 'celebraciones':
            return (f"{slug}.md", f"celebraciones/{slug}")
        elif parent_slug == 'formacion':
            return (f"{slug}.md", f"catequesis/{slug}")
    
    return (f"{slug}.md", slug)


def remap_image_paths(md_content, attachment_map):
    """Remap WordPress image URLs to local static paths."""
    wp_url_pattern = re.compile(
        r'https?://(?:www\.)?parroquiasanpablodelacruz\.com/wp-content/uploads/([^\s\")\]]+)',
        re.IGNORECASE
    )
    
    def replace_url(match):
        relative_path = match.group(1)
        local_src = UPLOADS_DIR / relative_path
        if local_src.exists():
            local_dst = OUTPUT_IMAGES / relative_path
            local_dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(local_src, local_dst)
        return f"/images/wp-content/{relative_path}"
    
    md_content = wp_url_pattern.sub(replace_url, md_content)
    return md_content


def process_shortcodes(md_content):
    """Convert or strip known WordPress shortcodes."""
    md_content = re.sub(
        r'\[caption[^\]]*\](.*?)\[/caption\]',
        r'\1',
        md_content,
        flags=re.DOTALL | re.IGNORECASE
    )
    
    md_content = re.sub(
        r'\[huge_it_gallery[^\]]*\]',
        '\n*Galería de imágenes — ver página original para fotos.*\n',
        md_content,
        flags=re.IGNORECASE
    )
    
    md_content = re.sub(
        r'\[gallery[^\]]*\]',
        '\n*Galería de imágenes — ver página original para fotos.*\n',
        md_content,
        flags=re.IGNORECASE
    )
    
    md_content = re.sub(
        r'\[(\w+)[^\]]*\](.*?)\[/\1\]',
        r'\2',
        md_content,
        flags=re.DOTALL | re.IGNORECASE
    )
    md_content = re.sub(
        r'\[(\w+)[^\]]*\]',
        '',
        md_content,
        flags=re.IGNORECASE
    )
    
    return md_content


def generate_redirects(pages, posts):
    """Generate Caddy redirect rules for old WordPress URLs."""
    lines = ["# WordPress → Static redirects", ""]
    
    for page in pages:
        if page['post_status'] != 'publish':
            continue
        _, new_path = determine_section(page, {p['ID']: p for p in pages})
        if new_path:
            lines.append(f"redir /?page_id={page['ID']} /{new_path} permanent")
    
    for post in posts:
        if post['post_status'] != 'publish':
            continue
        new_path = clean_slug(post['post_name'])
        lines.append(f"redir /?p={post['ID']} /posts/{new_path} permanent")
    
    lines.append("")
    lines.append("# WordPress system redirects")
    lines.append("redir /wp-admin / permanent")
    lines.append("redir /wp-login.php / permanent")
    lines.append("redir /wp-content/uploads/{path*} /images/wp-content/{path} permanent")
    
    return "\n".join(lines)


def main():
    if not SQL_FILE.exists():
        print(f"ERROR: SQL file not found: {SQL_FILE}")
        sys.exit(1)
    
    print(f"Reading {SQL_FILE}...")
    with open(SQL_FILE, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    
    field_names = [
        'ID', 'post_author', 'post_date', 'post_date_gmt', 'post_content',
        'post_title', 'post_excerpt', 'post_status', 'comment_status',
        'ping_status', 'post_password', 'post_name', 'to_ping', 'pinged',
        'post_modified', 'post_modified_gmt', 'post_content_filtered',
        'post_parent', 'guid', 'menu_order', 'post_type', 'post_mime_type', 'comment_count'
    ]
    
    print("Parsing database rows...")
    all_rows = parse_sql_rows(content, '2Bas0_posts', field_names)
    print(f"Found {len(all_rows)} total rows")
    
    pages = [r for r in all_rows if r.get('post_type') == 'page']
    posts = [r for r in all_rows if r.get('post_type') == 'post']
    attachments = [r for r in all_rows if r.get('post_type') == 'attachment']
    
    print(f"Pages: {len(pages)}, Posts: {len(posts)}, Attachments: {len(attachments)}")
    
    attachment_map = {}
    for att in attachments:
        att_id = att.get('ID')
        guid = att.get('guid', '')
        if att_id and guid:
            attachment_map[att_id] = att
    
    pages_by_id = {p['ID']: p for p in pages}
    
    used_paths = set()
    processed = 0
    
    for page in pages:
        if page['post_status'] != 'publish':
            continue
        
        title = page['post_title'].strip()
        slug = clean_slug(page['post_name'])
        if not title and slug not in SLUG_MAP:
            continue
        if not title:
            title = SLUG_MAP.get(slug, (None, None))[1] or slug
            title = title.replace('-', ' ').title()
        
        filename, url_path = determine_section(page, pages_by_id)
        
        original_url_path = url_path
        counter = 1
        while url_path in used_paths and url_path:
            url_path = f"{original_url_path}-{counter}"
            filename = f"{filename[:-3]}-{counter}.md"
            counter += 1
        used_paths.add(url_path)
        
        html = page.get('post_content', '')
        md = html_to_markdown(html)
        md = process_shortcodes(md)
        md = remap_image_paths(md, attachment_map)
        
        front_matter = f"""---
title: "{title or 'Sin título'}"
date: {page['post_date']}
lastmod: {page['post_modified']}
"""
        if page.get('post_excerpt'):
            front_matter += f"description: \"{page['post_excerpt']}\"\n"
        
        front_matter += "---\n\n"
        
        full_content = front_matter + md
        
        if url_path:
            if filename == '_index.md':
                out_dir = OUTPUT_PAGES
            else:
                out_dir = OUTPUT_PAGES / url_path
                out_dir.mkdir(parents=True, exist_ok=True)
                filename = '_index.md'
            out_path = out_dir / filename
        else:
            out_path = OUTPUT_PAGES / filename
        
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(full_content)
        processed += 1
        print(f"  Page: {title or '(no title)'} -> {out_path.relative_to(PROJECT_ROOT)}")
    
    for post in posts:
        if post['post_status'] != 'publish':
            continue
        
        title = post['post_title'].strip()
        slug = clean_slug(post['post_name'])
        
        html = post.get('post_content', '')
        md = html_to_markdown(html)
        md = process_shortcodes(md)
        md = remap_image_paths(md, attachment_map)
        
        front_matter = f"""---
title: "{title or 'Sin título'}"
date: {post['post_date']}
lastmod: {post['post_modified']}
"""
        if post.get('post_excerpt'):
            front_matter += f"description: \"{post['post_excerpt']}\"\n"
        
        # Aliases for query strings don't work well as static filenames;
        # redirects are handled by Caddy in migration/redirects.caddy
        # front_matter += f"aliases:\n  - /?p={post['ID']}\n"
        front_matter += "---\n\n"
        
        out_path = OUTPUT_POSTS / f"{slug}.md"
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(front_matter + md)
        processed += 1
        print(f"  Post: {title} -> {out_path.relative_to(PROJECT_ROOT)}")
    
    redirects = generate_redirects(pages, posts)
    with open(REDIRECTS_FILE, 'w', encoding='utf-8') as f:
        f.write(redirects)
    print(f"\nWrote redirects to {REDIRECTS_FILE}")
    
    print(f"\nMigration complete. {processed} items written.")
    print(f"Images copied to: {OUTPUT_IMAGES}")


if __name__ == '__main__':
    main()
