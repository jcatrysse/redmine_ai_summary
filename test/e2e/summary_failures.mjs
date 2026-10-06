// Generation that fails, and how the issue page shows it: no API key (nothing
// may reach the provider), a key the provider refuses, empty content, an
// endpoint that does not answer, and debug logging.
import { e2e } from '../../.codex/e2e/lib.mjs';
import ai from './support/ai.cjs';

const t = await e2e('summary_failures');
await ai.startLlm();
ai.resetSummaries();
const id = ai.issueId('E2E closed issue');
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };
const errorOf = () => t.page.locator('#issue-summary [data-action=copy_error]').getAttribute('data-error-message');

async function generateAndWait(expected) {
  await t.go(`/issues/${id}`);
  await Promise.all([
    t.page.waitForResponse(r => r.request().method() === 'POST' && r.url().endsWith('/ai_summaries')),
    t.page.click('#generate-summary-button'),
  ]);
  await t.page.waitForTimeout(500); // create.js has replaced the block and started polling
  await t.page.waitForSelector(`#issue-summary[data-status="${expected}"]`, { timeout: 20000 }).catch(() => {});
  await t.page.waitForTimeout(300);
  await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
  return t.page.locator('#issue-summary').getAttribute('data-status');
}

await t.login('manager');
await t.page.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: t.BASE });
t.page.on('dialog', d => d.accept());

// no API key: refused before anything is sent
ai.pluginSettings({ api_key: '' });
let mark = ai.llmMark();
let status = await generateAndWait('stale');
assert(status === 'stale', `no key -> stale (got ${status})`);
assert(await errorOf() === 'API key is missing.', `no key error: ${await errorOf()}`);
assert(ai.llmRequests(mark).length === 0, `no request reached the provider without a key (${ai.llmRequests(mark).length})`);
assert(await t.page.locator('#issue-summary [data-action=copy_error] svg use').count() === 1, 'error marker has the warning icon');
await t.page.locator('#issue-summary [data-action=copy_error]').hover();
await t.shot('no-api-key', 'No API key: the failed state and the warning marker; its message (checked, not visible in the picture) is "API key is missing.", and the fake provider received no request');

// the error marker copies the message
await t.page.locator('#issue-summary [data-action=copy_error]').click();
await t.page.waitForTimeout(300);
const clip = await t.page.evaluate(() => navigator.clipboard.readText());
assert(clip === 'API key is missing.', `error copied: ${clip}`);
await t.shot('error-copied', 'Clicking the warning marker copies the error message and shows a notice');

// a key the provider refuses
ai.pluginSettings({ api_key: 'wrong-key' });
mark = ai.llmMark();
status = await generateAndWait('stale');
assert(status === 'stale', `wrong key -> stale (got ${status})`);
assert(/401|Invalid API key|status 401/i.test(await errorOf() || ''), `wrong key error: ${await errorOf()}`);
assert(ai.llmRequests(mark).some(r => r.auth === 'Bearer wrong-key'), 'request with the wrong key');
await t.page.locator('#issue-summary [data-action=copy_error]').hover();
await t.shot('wrong-key', `Provider refuses the key (HTTP 401): failed state; marker message "${(await errorOf() || '').slice(0, 80)}"`);

// empty content
ai.pluginSettings({ model: 'e2e-empty' });
status = await generateAndWait('stale');
assert(await errorOf() === 'AI Summary returned empty content', `empty content error: ${await errorOf()}`);
await t.shot('empty-content', 'Provider answers with empty content: failed state, "AI Summary returned empty content"');

// endpoint not answering
ai.pluginSettings({ api_endpoint: 'http://127.0.0.1:9/v1' });
status = await generateAndWait('stale');
assert(/Failed to open TCP connection|Connection refused/.test(await errorOf() || ''), `unreachable error: ${await errorOf()}`);
await t.shot('unreachable', 'Endpoint does not answer: failed state with the connection error; the issue page still works');

// debug logging: the request/response payload is kept with the summary
ai.pluginSettings({ debug_logging: '1' });
status = await generateAndWait('up_to_date');
assert(status === 'up_to_date', `debug: generated (got ${status})`);
const payload = JSON.parse(await errorOf() || '{}');
assert(payload.request?.subject === 'E2E closed issue' && payload.response?.choices, 'debug payload kept');
await t.shot('debug-logging', 'Debug logging on: the summary is generated and the marker holds the request and response payload');
ai.pluginSettings();

await t.done();
