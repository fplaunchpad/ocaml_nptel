#!/usr/bin/env python3
"""Generate the README course counts from lecture frontmatter.

Use --write to refresh; the default checks for documentation drift.
"""
from collections import Counter
from pathlib import Path
import re
import sys
import textwrap

ROOT = Path(__file__).resolve().parent.parent
START = '<!-- course-inventory:start -->'
END = '<!-- course-inventory:end -->'


def inventory():
    modules = Counter()
    practice = 0
    for path in sorted((ROOT / 'lectures').glob('M*-L*.md')):
        frontmatter = path.read_text().split('---', 2)[1]
        week = int(re.search(r'^week: (\d+)$', frontmatter, re.M)[1])
        title = re.search(r'^title: (.+)$', frontmatter, re.M)[1].strip('"\'')
        modules[week] += 1
        practice += title.startswith('Practice:')
    total = sum(modules.values())
    counts = ', '.join(str(modules[week]) for week in sorted(modules))
    return '\n'.join(textwrap.wrap(
        f'{total} lecture files: {total - practice} non-practice chapters and '
        f'{practice} practice worksheets. Module file counts (M01-M12): {counts}.',
        width=70))


def main():
    path = ROOT / 'README.md'
    source = path.read_text()
    before, rest = source.split(START, 1)
    _, after = rest.split(END, 1)
    expected = before + START + '\n' + inventory() + '\n' + END + after
    if sys.argv[1:] == ['--write']:
        path.write_text(expected)
    elif expected != source:
        print('Course counts are stale: run python3 tools/course-inventory.py --write')
        return 1
    print(inventory())
    return 0


if __name__ == '__main__':
    sys.exit(main())
