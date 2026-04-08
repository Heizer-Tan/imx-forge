#!/usr/bin/env python3
"""
@file check_links.py
@brief Check all links in the local MkDocs site for 404 errors
@date 2026-04-08

Usage:
    python scripts/document/check_links.py [OPTIONS]

Options:
    --url URL        Base URL to check (default: http://127.0.0.1:8000)
    --timeout SEC    Request timeout in seconds (default: 5)
    --ignore PATH    Ignore paths matching this pattern (can be used multiple times)
    --verbose        Show detailed output
    --help           Show this help message

Examples:
    # Check default URL (assumes mkdocs serve is running)
    python scripts/document/check_links.py

    # Check custom URL
    python scripts/document/check_links.py --url http://localhost:8080

    # Ignore certain paths
    python scripts/document/check_links.py --ignore /api/ --ignore /external/
"""

import argparse
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Set, List, Tuple
from urllib.parse import urljoin, urlparse

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError as e:
    print(f"Error: Missing required dependency: {e}", file=sys.stderr)
    print("Install with: pip install requests beautifulsoup4", file=sys.stderr)
    sys.exit(1)


# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[0;33m'
    CYAN = '\033[0;36m'
    GRAY = '\033[0;90m'
    NC = '\033[0m'  # No Color


def log_info(msg: str):
    print(f"{Colors.CYAN}[INFO]{Colors.NC} {msg}")


def log_success(msg: str):
    print(f"{Colors.GREEN}[OK]{Colors.NC} {msg}")


def log_error(msg: str):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}", file=sys.stderr)


def log_warn(msg: str):
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {msg}")


def log_verbose(msg: str):
    print(f"{Colors.GRAY}[VERBOSE]{Colors.NC} {msg}")


class LinkChecker:
    def __init__(self, base_url: str, timeout: int = 5, ignore_patterns: List[str] = None, verbose: bool = False):
        # Ensure base_url ends with / for correct urljoin behavior
        self.base_url = base_url if base_url.endswith('/') else base_url + '/'
        self.timeout = timeout
        self.ignore_patterns = [re.compile(p) for p in (ignore_patterns or [])]
        self.verbose = verbose

        # Tracking
        self.visited: Set[str] = set()
        self.to_visit: Set[str] = set()
        self.errors: List[Tuple[str, int, str]] = []
        self.success: Set[str] = set()

    def is_internal_url(self, url: str, base_url: str = None) -> bool:
        """Check if URL is within the same domain."""
        if base_url is None:
            base_url = self.base_url
        parsed = urlparse(url)
        base_parsed = urlparse(base_url)
        return parsed.netloc == '' or parsed.netloc == base_parsed.netloc

    def normalize_url(self, url: str, base_url: str = None) -> str:
        """Normalize URL for comparison."""
        if base_url is None:
            base_url = self.base_url
        if url.startswith('//'):
            url = 'https:' + url
        if not url.startswith('http'):
            url = urljoin(base_url, url)
        # Remove fragment
        url = url.split('#')[0]
        return url

    def should_ignore(self, url: str) -> bool:
        """Check if URL should be ignored."""
        for pattern in self.ignore_patterns:
            if pattern.search(url):
                return True
        return False

    def check_url(self, url: str) -> Tuple[str, int, str]:
        """Check a single URL and return (url, status_code, error_message)."""
        try:
            response = requests.get(url, timeout=self.timeout, allow_redirects=True)
            return (url, response.status_code, '')
        except requests.exceptions.Timeout:
            return (url, 0, 'Timeout')
        except requests.exceptions.ConnectionError:
            return (url, 0, 'Connection error')
        except Exception as e:
            return (url, 0, str(e))

    def extract_links(self, html: str, base_url: str) -> Set[str]:
        """Extract all links from HTML."""
        # Ensure base_url ends with / for correct urljoin behavior
        if not base_url.endswith('/'):
            base_url = base_url + '/'

        links = set()
        soup = BeautifulSoup(html, 'html.parser')

        for tag in soup.find_all(['a', 'link', 'area'], href=True):
            href = tag['href']
            url = self.normalize_url(href, base_url)
            if self.is_internal_url(url, base_url):
                links.add(url)

        for tag in soup.find_all(['img', 'script'], src=True):
            src = tag['src']
            url = self.normalize_url(src, base_url)
            if self.is_internal_url(url, base_url):
                links.add(url)

        return links

    def crawl(self, start_url: str = None):
        """Crawl the site and check all links."""
        if start_url is None:
            start_url = self.base_url

        self.to_visit.add(start_url)
        log_info(f"Starting crawl from: {start_url}")

        with ThreadPoolExecutor(max_workers=10) as executor:
            while self.to_visit:
                # Get batch of URLs to check
                batch = list(self.to_visit)[:50]
                self.to_visit.difference_update(batch)

                # Check URLs in parallel
                futures = {executor.submit(self.check_url, url): url for url in batch}

                for future in as_completed(futures):
                    url, status, error = future.result()

                    if url in self.visited:
                        continue
                    self.visited.add(url)

                    # Skip non-internal URLs
                    if not self.is_internal_url(url):
                        continue

                    # Skip ignored patterns
                    if self.should_ignore(url):
                        if self.verbose:
                            log_verbose(f"Ignored: {url}")
                        continue

                    if status == 200:
                        self.success.add(url)
                        if self.verbose:
                            log_verbose(f"OK: {url}")

                        # Extract links from successful HTML pages
                        if url.endswith('/') or url.endswith('.html') or '.' not in url.split('/')[-1]:
                            try:
                                response = requests.get(url, timeout=self.timeout)
                                if 'text/html' in response.headers.get('Content-Type', ''):
                                    links = self.extract_links(response.text, url)
                                    for link in links:
                                        if link not in self.visited and not self.should_ignore(link):
                                            self.to_visit.add(link)
                            except Exception as e:
                                if self.verbose:
                                    log_verbose(f"Failed to extract links from {url}: {e}")

                    elif status == 404:
                        self.errors.append((url, status, 'Not Found'))
                        log_error(f"404: {url}")
                    elif status >= 400:
                        self.errors.append((url, status, f'HTTP {status}'))
                        log_warn(f"{status}: {url}")
                    elif status == 0:
                        self.errors.append((url, status, error))
                        log_error(f"{error}: {url}")

                # Show progress
                if self.verbose and len(self.visited) % 50 == 0:
                    log_info(f"Progress: {len(self.visited)} URLs checked")

    def print_summary(self):
        """Print summary of results."""
        total = len(self.visited)
        success = len(self.success)
        errors = len(self.errors)

        print()
        log_info("=" * 50)
        log_info("Link Check Summary")
        log_info("=" * 50)
        print(f"  Total URLs checked: {total}")
        print(f"{Colors.GREEN}  Successful:         {success}{Colors.NC}")
        print(f"{Colors.RED}  Errors:             {errors}{Colors.NC}")
        print()

        if self.errors:
            log_error("Errors found:")
            for url, status, error in sorted(self.errors):
                print(f"  [{status}] {url} - {error}")
            print()
            return False
        else:
            log_success("No errors found!")
            return True


def main():
    parser = argparse.ArgumentParser(
        description='Check all links in the local MkDocs site for 404 errors',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--url',
        default='http://127.0.0.1:8000',
        help='Base URL to check (default: http://127.0.0.1:8000)'
    )
    parser.add_argument(
        '--timeout',
        type=int,
        default=5,
        help='Request timeout in seconds (default: 5)'
    )
    parser.add_argument(
        '--ignore',
        action='append',
        default=[],
        help='Ignore paths matching this pattern (can be used multiple times)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Show detailed output'
    )

    args = parser.parse_args()

    # Check if server is running
    log_info(f"Checking if server is running at {args.url}...")
    try:
        response = requests.get(args.url, timeout=5)
        log_success(f"Server is running (status: {response.status_code})")
    except Exception as e:
        log_error(f"Cannot connect to server: {e}")
        log_info("Make sure 'mkdocs serve' is running first")
        log_info("Or use: ./scripts/document/mkdocs_dev.sh serve")
        sys.exit(1)

    # Run link checker
    checker = LinkChecker(
        base_url=args.url,
        timeout=args.timeout,
        ignore_patterns=args.ignore,
        verbose=args.verbose
    )
    checker.crawl()
    success = checker.print_summary()

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
