// A cold worker can outlast the quiz UI's deadline. Retry that verdict
// once in the same context; explicit failures and thrown errors are final.
export async function withQuizTimeoutRetry(check, onRetry = () => {}) {
  const first = await check();
  if (first.text.trim() !== 'Timed out') return first;
  onRetry();
  const second = await check();
  if (second.text.trim() === 'Timed out') {
    throw new Error('Quiz timed out after two attempts');
  }
  return second;
}

// A timeout is inconclusive even when the answer is expected to fail.
export async function checkQuizVerdict(check, expected, onRetry) {
  const verdict = await withQuizTimeoutRetry(check, onRetry);
  if (!verdict.classes.split(/\s+/).includes(expected)) {
    throw new Error(`Expected ${expected}, got ${verdict.text}`);
  }
  return verdict;
}
