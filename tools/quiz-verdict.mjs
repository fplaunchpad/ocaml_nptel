// A cold worker can outlast the quiz UI's deadline. Retry that verdict
// once in the same context; explicit failures and thrown errors are final.
export async function withQuizTimeoutRetry(check, onRetry = () => {}) {
  const first = await check();
  if (first.text.trim() !== 'Timed out') return first;
  onRetry();
  return check();
}
