import test from 'node:test';
import assert from 'node:assert/strict';
import { withQuizTimeoutRetry, checkQuizVerdict } from './quiz-verdict.mjs';

for (const [name, texts, expectedCalls] of [
  ['passes immediately', ['All tests pass'], 1],
  ['retries a timeout', ['Timed out', 'All tests pass'], 2],
  ['preserves a failure', ['Some tests failed'], 1],
  ['preserves failure on retry', ['Timed out', 'Some tests failed'], 2],
]) {
  test(name, async () => {
    let calls = 0;
    let retries = 0;
    const verdict = await withQuizTimeoutRetry(
      async () => ({ text: texts[calls++] }), () => retries++);
    assert.equal(calls, expectedCalls);
    assert.equal(retries, expectedCalls - 1);
    assert.equal(verdict.text, texts.at(-1));
  });
}

test('does not retry a thrown browser error', async () => {
  let calls = 0;
  await assert.rejects(withQuizTimeoutRetry(async () => {
    calls++;
    throw new Error('browser disconnected');
  }), /browser disconnected/);
  assert.equal(calls, 1);
});

for (const expected of ['pass', 'fail']) {
  test(`double timeout cannot satisfy expected ${expected}`, async () => {
    let calls = 0;
    await assert.rejects(checkQuizVerdict(async () => {
      calls++;
      return { classes: 'quiz-status fail', text: 'Timed out' };
    }, expected), /timed out after two attempts/);
    assert.equal(calls, 2);
  });
  test(`completed ${expected} verdict is accepted`, async () => {
    const verdict = { classes: `quiz-status ${expected}`, text: 'Completed' };
    assert.equal(await checkQuizVerdict(async () => verdict, expected), verdict);
  });
  test(`wrong verdict cannot satisfy expected ${expected}`, async () => {
    const other = expected === 'pass' ? 'fail' : 'pass';
    await assert.rejects(checkQuizVerdict(async () => ({
      classes: `quiz-status ${other}`, text: 'Completed',
    }), expected), /Expected/);
  });
}
