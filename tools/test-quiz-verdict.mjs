import test from 'node:test';
import assert from 'node:assert/strict';
import { withQuizTimeoutRetry } from './quiz-verdict.mjs';

for (const [name, texts, expectedCalls] of [
  ['passes immediately', ['All tests pass'], 1],
  ['retries a timeout', ['Timed out', 'All tests pass'], 2],
  ['stops after a second timeout', ['Timed out', 'Timed out'], 2],
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
