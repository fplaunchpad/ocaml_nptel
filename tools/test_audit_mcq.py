"""Regression checks for the single-choice MCQ authoring contract."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'audit_mcq', Path(__file__).with_name('audit-mcq-length.py'))
audit_mcq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit_mcq)


class McqChoices(unittest.TestCase):
    def audit(self, options):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'lecture.md'
            path.write_text(':::quiz mcq id=example\n' + options + '\n:::\n')
            return audit_mcq.audit(path)

    def test_single_correct(self):
        self.assertEqual(self.audit('- [x] yes\n- [ ] no!'), [])

    def test_uppercase_correct(self):
        self.assertEqual(self.audit('- [X] yes\n- [ ] no!'), [])

    def test_missing_correct(self):
        with self.assertRaisesRegex(ValueError, 'found 0'):
            self.audit('- [ ] yes\n- [ ] no!')

    def test_multiple_correct(self):
        with self.assertRaisesRegex(ValueError, 'found 2'):
            self.audit('- [x] yes\n- [x] no!')

    def test_empty(self):
        with self.assertRaisesRegex(ValueError, 'found 0'):
            self.audit('A question with no options.')

    def test_no_distractors(self):
        with self.assertRaisesRegex(ValueError, 'at least two options'):
            self.audit('- [x] yes')


if __name__ == '__main__':
    unittest.main()
