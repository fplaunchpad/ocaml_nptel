#!/usr/bin/env python3
"""Run reviewed quiz references and regression answers against the authored tests.

Run with: opam exec -- python3 tools/check-quiz-solutions.py
The manifest states the covered quizzes and their prerequisite code fences.
Each answer gets a fresh OCaml toplevel; no bindings or mutable state leak
between cases. References and assertions are extracted from lecture source,
including unlabelled references and solutions split over adjacent disclosures.
This supplements MDX, which skips quiz assertion cells.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
FENCES = re.compile(r'^```([^\n]*)\n(.*?)^```\s*$', re.M | re.S)


def code_blocks(text):
    return [m.group(2) for m in FENCES.finditer(text)
            if m.group(1).strip() in ('', 'ocaml')]


def div_end(source, start):
    """Find a balanced fenced div, ignoring div-looking text in code fences."""
    depth = 0
    fenced = False
    for line in source[start:].splitlines(keepends=True):
        if line.lstrip().startswith('```'):
            fenced = not fenced
        elif not fenced:
            if line.strip() == ':::':
                depth -= 1
                if depth == 0:
                    return start + len(line)
            elif line.lstrip().startswith(':::'):
                depth += 1
        start += len(line)
    raise ValueError('unterminated fenced div')


def extract(case):
    source = (ROOT / 'lectures' / case['file']).read_text()
    match = re.search(r'^:::quiz code id=' + re.escape(case['id']) + r'\s*$', source, re.M)
    if not match:
        raise ValueError('quiz not found: ' + case['id'])
    end = div_end(source, match.start())
    blocks = list(FENCES.finditer(source[match.start():end]))
    if len(blocks) != 2:
        raise ValueError('expected one starter and one test cell: ' + case['id'])
    starter, tests = [m.group(2) for m in blocks]
    references = []
    pos = end
    while True:
        following = re.match(r'\s*:::solution\s*\n', source[pos:])
        if not following:
            break
        begin = source.index(':::solution', pos)
        pos = div_end(source, begin)
        references.extend(code_blocks(source[begin:pos]))
    if not references:
        raise ValueError('reference solution not found: ' + case['id'])
    prerequisites = []
    preceding = code_blocks(source[:match.start()])
    for anchor in case.get('setup', []):
        found = [block for block in preceding if anchor in block]
        if not found:
            raise ValueError('prerequisite not found: ' + anchor)
        prerequisites.append(found[-1])
    return prerequisites, starter, '\n;;\n'.join(references), tests


def run_answer(parts, answer, oxcaml=False):
    setup, starter, _, tests = parts
    with tempfile.TemporaryDirectory(prefix='quiz-check-') as dirname:
        folder = Path(dirname)
        # Starters often provide required types, signatures and helpers. Their
        # intentional errors are outside the checked answer/result segment.
        stages = [('setup', '\n;;\n'.join(setup)), ('starter', starter),
                  ('answer', answer), ('tests', tests)]
        for name, code in stages:
            (folder / (name + '.ml')).write_text(code)
        commands = '''#use "topfind";;
#require "qcheck";;
#require "ounit2";;
open OUnit2;;
'''
        commands += '#use ' + json.dumps(str(ROOT / 'lectures/mdx_prelude.ml')) + ';;\n'
        if oxcaml:
            commands = ''
        commands += '''#use "setup.ml";;
print_endline "QUIZ_STARTER_BEGIN";;
#use "starter.ml";;
print_endline "QUIZ_ANSWER_BEGIN";;
#use "answer.ml";;
#use "tests.ml";;
print_endline "QUIZ_ANSWER_END";;
'''
        result = subprocess.run(['ocaml', '-noinit', '-noprompt'], input=commands,
                                text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, cwd=folder, timeout=30)
        output = result.stdout.split('QUIZ_ANSWER_BEGIN\n', 1)[-1]
        initialization = result.stdout.split('QUIZ_STARTER_BEGIN\n', 1)[0]
        if re.search(r'Error:|Exception:', initialization):
            return False, 'Quiz prerequisites failed:\n' + initialization
        passed = (result.returncode == 0 and 'QUIZ_ANSWER_END\n' in output
                  and 'all tests passed\n' in output
                  and not re.search(r'Error:|Exception:', output))
        return passed, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ids', nargs='*', help='optional quiz IDs to check')
    parser.add_argument('--oxcaml', action='store_true',
                        help='run OxCaml cases under the current OxCaml switch')
    parser.add_argument('--export-browser-fixtures', action='store_true',
                        help='emit source-derived answers for the browser check')
    args = parser.parse_args()
    cases = json.loads((ROOT / 'tools/quiz-regressions.json').read_text())
    selected = [c for c in cases
                if (not args.ids or c['id'] in args.ids)
                and (args.export_browser_fixtures
                     or (c.get('runtime') == 'oxcaml') == args.oxcaml)]
    if not selected or set(args.ids) - {c['id'] for c in selected}:
        parser.error('unknown quiz ID')
    failures = []
    count = 0
    fixtures = []
    for case in selected:
        parts = extract(case)
        answers = [('reference', parts[2], True), ('starter', '', False)]
        for mutant in case.get('mutants', []):
            if 'code' in mutant:
                answer = mutant['code']
            else:
                old, new = mutant['replace']
                if old not in parts[2]:
                    raise ValueError(f"stale mutant {case['id']}: {mutant['name']}")
                answer = parts[2].replace(old, new)
            answers.append((mutant['name'], answer, False))
        if args.export_browser_fixtures:
            fixtures.append(dict(id=case['id'], file=case['file'], answers=[
                dict(name=name, source=parts[1] + '\n;;\n' + answer, passed=expected)
                for name, answer, expected in answers]))
            continue
        for name, answer, expected in answers:
            passed, output = run_answer(parts, answer, oxcaml=args.oxcaml)
            count += 1
            if passed != expected:
                failures.append(f"{case['id']} / {name}: unexpected verdict\n{output}")
        print(f"checked {case['id']}: {len(answers)} answers", flush=True)
    if args.export_browser_fixtures:
        print(json.dumps(fixtures))
        return
    if failures:
        raise SystemExit('\n\n'.join(failures))
    print(f'All {count} answer checks passed across {len(selected)} quizzes.')


if __name__ == '__main__':
    main()
