#!/usr/bin/env node
// Check the browser grading verdict, including success signalling and edits
// after a pass. All answers come from the same lecture/manifest extraction as CI.
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { checkQuizVerdict } from './quiz-verdict.mjs';

const checker = fileURLToPath(new URL('./check-quiz-solutions.py', import.meta.url));
const fixtures = JSON.parse(execFileSync('python3', [checker, '--export-browser-fixtures', ...process.argv.slice(3)], {
  encoding: 'utf8', maxBuffer: 4 * 1024 * 1024,
}));
const base = (process.argv[2] || 'http://localhost:8765/_site').replace(/\/$/, '');
const browser = await chromium.launch({ headless: true });
let count = 0;
try {
  for (const fixture of fixtures) {
    const context = await browser.newContext();
    const page = await context.newPage();
    // Local verification must not submit quiz analytics or load remote content.
    await page.route('https://**/*', route => route.abort());
    await page.goto(`${base}/${fixture.file.replace(/\.md$/, '.html')}`);
    const id = fixture.id.toLowerCase();
    await page.waitForFunction(id =>
      document.querySelector(`[data-quiz-id="${id}"] .quiz-check`), id,
      { timeout: 60_000 });
    const quiz = page.locator(`[data-quiz-id="${id}"]`);
    async function checkAnswer(answer) {
      await quiz.locator('x-ocaml:not([data-quiz-test])').evaluate((cell, source) => {
        cell.textContent = source;
      }, answer.source);
      const expected = answer.passed ? 'pass' : 'fail';
      try {
        await checkQuizVerdict(async () => {
          await quiz.locator('.quiz-check').click();
          await page.waitForFunction(id => {
            const status = document.querySelector(`[data-quiz-id="${id}"] .quiz-status`);
            return status && !status.classList.contains('running');
          }, id, { timeout: 30_000 });
          const status = quiz.locator('.quiz-status');
          return {
            classes: await status.getAttribute('class'),
            text: await status.textContent(),
          };
        }, expected, () => console.log(`retrying ${fixture.id} / ${answer.name}: timed out`));
      } catch (error) {
        const output = await quiz.locator('[data-quiz-test]').evaluate(cell =>
          [...cell.shadowRoot.querySelectorAll('.caml_meta, .caml_stdout, .caml_stderr')]
            .map(node => node.textContent).join('\n'));
        throw new Error(`${fixture.id} / ${answer.name}: ${error.message}\n${output}`);
      }
    }
    for (const answer of fixture.answers) {
      await checkAnswer(answer);
      count++;
    }
    // Recovery matters too: a corrected answer must pass after failed edits.
    await checkAnswer({ ...fixture.answers[0], name: 'recovery' });
    console.log(`checked ${fixture.id}: ${fixture.answers.length} answers and recovery`);
    await context.close();
  }
  console.log(`All ${count} browser verdicts and ${fixtures.length} recoveries passed.`);
} finally {
  await browser.close();
}
