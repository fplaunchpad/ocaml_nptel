#!/usr/bin/env node
// Run against an extracted archive's index.html. Block all network requests.
import assert from 'node:assert/strict';
import { chromium, firefox, webkit } from 'playwright';

import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
const input = process.argv[2];
if (!input) throw new Error('Usage: node tools/playwright-offline-check.mjs /path/to/index.html');
const index = input.startsWith('file:') ? input : pathToFileURL(resolve(input)).href;
assert.equal(new URL(index).protocol, 'file:');
const base = new URL('.', index).href.replace(/\/$/, '');
const engine = process.env.BROWSER || 'chromium';
const browser = await ({chromium, firefox, webkit}[engine]).launch({ headless: true });
try {
  const context = await browser.newContext();
  // WebKit's emulated offline mode also rejects file:// navigation.
  // The route below blocks network traffic in every engine.
  if (engine !== 'webkit') await context.setOffline(true);
  const errors = [];
  await context.route(/^https?:\/\//, route => route.abort());
  const page = await context.newPage();
  page.on('pageerror', error => { errors.push(error.message); console.error(error.message); });
  page.on('response', response => {
    if (response.url().startsWith(base + '/') && response.status() >= 400)
      errors.push(`${response.status()} ${response.url()}`);
  });
  await page.goto(index);
  await page.locator('#lecture-search').fill('recursion');
  await page.locator('#search-results a').first().waitFor();
  await page.locator('#search-results a').first().click();
  await page.waitForSelector('x-ocaml .run_btn button');
  await page.locator('.mode-toggle').click();
  await page.waitForFunction(() => window.Reveal?.isReady());
  const before = await page.evaluate(() => window.Reveal.getIndices().h);
  await page.keyboard.press('ArrowRight');
  await page.waitForFunction(before => window.Reveal.getIndices().h > before, before);
  console.log('search, chapter navigation, and slides passed');

  for (const file of ['M02-L01-literals', 'M09-L05-property-based-testing',
                      'M11-L02-uniqueness']) {
    await page.goto(`${base}/${file}.html`);
    await page.waitForFunction(() => customElements.get('x-ocaml'), null,
                              { timeout: 90_000 });
    await page.waitForFunction(() => document.querySelector('x-ocaml')?.shadowRoot
      ?.querySelector('style[data-nptel-cell-style]'), null, {timeout: 90_000});
    // Edit and run the actual first cell after the page has wired its
    // controls. Later cells can intentionally contain teaching errors.
    const cell = page.locator('x-ocaml').first();
    await cell.evaluate(cell => { cell.textContent = 'print_endline "OFFLINE_RUNTIME_OK";;'; });
    await cell.locator('.run_btn button').click();
    await page.waitForFunction(() =>
      document.querySelector('x-ocaml').shadowRoot
        ?.querySelector('.caml_stdout')?.textContent.includes('OFFLINE_RUNTIME_OK'),
      null, { timeout: 90_000 });
    console.log(`${file}: runtime executed offline`);
  }

  await page.goto(`${base}/M01-L01-course-intro.html`);
  await page.locator('.vm-start').click();
  await page.waitForFunction(() => document.querySelector('.vm-terminal')?.vmEmulator,
                            null, { timeout: 60_000 });
  await page.evaluate(() => {
    window.offlineSerial = '';
    document.querySelector('.vm-terminal').vmEmulator.add_listener(
      'serial0-output-byte', b => { window.offlineSerial += String.fromCharCode(b); });
    // A fast local restore can print its prompt before automation attaches.
    document.querySelector('.vm-terminal').vmEmulator.serial0_send('\n');
  });
  await page.waitForFunction(() => window.offlineSerial.includes('hello# '), null,
                            { timeout: 120_000 });
  console.log('Linux VM shell ready');
  await page.locator('.vm-term').click();
  await page.keyboard.type('dune build && ./_build/default/hello.exe', { delay: 10 });
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => window.offlineSerial.includes('Hello from dune'),
                            null, { timeout: 180_000 });
  console.log('Linux VM booted, built, and ran hello with remote requests blocked');
  assert.deepEqual(errors, [], 'page errors or missing local resources');
} finally {
  await browser.close();
}
