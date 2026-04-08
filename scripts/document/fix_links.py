#!/usr/bin/env python3
"""
Fix markdown links in document files.
- Internal .md links: Remove .md extension for pretty URLs
- External .md links: Remove or convert to GitHub links
"""
import os
import re
from pathlib import Path

# Files/directories that are outside docs_dir and should be removed/ignored
EXTERNAL_REFS = {
    '../../README.md',
    '../../CONTRIBUTING.md',
    '../../CONTRIBUTORS.md',
    '../../QUICK_START.md',  # Already moved to document/
    '../README.md',
    '../CONTRIBUTING.md',
    '../CONTRIBUTORS.md',
}

# Base URL for GitHub links
GITHUB_BASE = 'https://github.com/Awesome-Embedded-Learning-Studio/imx-forge/blob/main/'


def should_remove_link(url: str) -> bool:
    """Check if link should be removed (external reference)."""
    # Check against external references list
    for ref in EXTERNAL_REFS:
        if ref in url:
            return True

    # Check for paths that go outside document/
    if url.count('../') >= 2:
        return True

    # Check for third_party, driver, rootfs paths
    if any(x in url for x in ['third_party', 'driver/', 'rootfs/overlay', 'rootfs/nfs']):
        return True

    return False


def convert_to_github_link(url: str) -> str:
    """Convert external link to GitHub URL."""
    # Remove ../ to get path from repo root
    path = url.replace('../', '')
    return f'{GITHUB_BASE}{path}'


def fix_markdown_file(filepath: Path) -> int:
    """Fix markdown links in a file. Return number of changes made."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    changes = 0

    # Pattern for markdown links: [text](url)
    def replace_link(match):
        nonlocal changes
        text = match.group(1)
        url = match.group(2)

        # Skip http/https links and anchors
        if url.startswith('http') or url.startswith('#') or url.startswith('javascript:'):
            return match.group(0)

        # Handle external references
        if should_remove_link(url):
            changes += 1
            # Keep the text but remove the link
            return text

        # Remove .md extension from internal links
        if url.endswith('.md'):
            new_url = url[:-3]  # Remove .md
            # For index files, use directory path
            if new_url.endswith('/index'):
                new_url = new_url[:-6]  # Remove /index
            changes += 1
            return f'[{text}]({new_url})'

        return match.group(0)

    # Replace markdown links
    content = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', replace_link, content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return changes
    return 0


def main():
    docs_dir = Path('document')

    if not docs_dir.exists():
        print(f"Error: {docs_dir} not found")
        return 1

    total_changes = 0
    total_files = 0

    for md_file in docs_dir.rglob('*.md'):
        changes = fix_markdown_file(md_file)
        if changes > 0:
            total_changes += changes
            total_files += 1
            print(f"Fixed {changes} link(s) in {md_file.relative_to(docs_dir)}")

    print(f"\nTotal: {total_changes} link(s) fixed in {total_files} file(s)")
    return 0


if __name__ == '__main__':
    exit(main())
