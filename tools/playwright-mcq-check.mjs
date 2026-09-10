#!/usr/bin/env node
// Exercise every option of the three repaired single-choice questions.
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const base = (process.argv[2] || 'http://localhost:8765/_site').replace(/\/$/, '');
const cases = [
  ['M04-L03-variants', 'm04-l03-q2', 1],
  ['M04-L04-recursive-types', 'm04-l04-q2', 2],
  ['M06-L03-filter', 'm06-l03-q2', 0],
];
const browser = await chromium.launch({ headless: true });
try {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.route('https://**/*', route => route.abort());
  for (const [file, id, correct] of cases) {
    await page.goto(`${base}/${file}.html`);
    const quiz = page.locator(`[data-quiz-id="${id}"]`);
    const choices = quiz.locator('input[type=radio]');
    await choices.first().waitFor();
    assert.equal(await choices.count(), 4, id);
    assert.equal(await quiz.locator('input[data-correct=true]').count(), 1, id);
    for (let index = 0; index < 4; index++) {
      await choices.nth(index).check();
      assert.equal(await quiz.evaluate(q => q.classList.contains('quiz-correct')),
        index === correct, `${id} option ${index}`);
      assert.equal(await quiz.locator('input:checked').count(), 1, id);
      assert.equal(await quiz.locator('.quiz-choice.wrong').count(),
        index === correct ? 0 : 1, id);
    }
    await page.reload();
    await choices.first().waitFor();
    assert.equal(await choices.nth(3).isChecked(), true, `${id} restored selection`);
    await choices.nth(correct).check();
    assert.equal(await quiz.evaluate(q => q.classList.contains('quiz-correct')),
      true, `${id} corrected selection`);
    console.log(`checked ${id}: four choices, persistence, and correction`);
  }
} finally {
  await browser.close();
}
