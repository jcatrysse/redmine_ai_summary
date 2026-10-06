// Automatic generation when a note is added: on, off, and "only when a summary
// already exists".
import { e2e } from '../../.codex/e2e/lib.mjs';
import ai from './support/ai.cjs';

const t = await e2e('auto_generate');
await ai.startLlm();
ai.resetSummaries();
const id = ai.issueId('E2E unassigned issue');
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };
const summaryCount = () => ai.rails(`print IssueSummary.where(issue_id: ${id}).count`);

async function addNote(text) {
  await t.go(`/issues/${id}`);
  await t.page.locator('.contextual a.icon-edit').first().click();
  await t.page.fill('#issue_notes', text);
  await t.page.locator('#issue-form input[type=submit][name=commit]').first().click();
  await t.settle();
  t.check('add note');
}

await t.login('manager');

// off: a note creates no summary
ai.pluginSettings({ auto_generate: '0' });
let mark = ai.llmMark();
await addNote('Note with automatic generation off.');
await t.page.waitForTimeout(3000);
assert(summaryCount() === '0' && ai.llmRequests(mark).length === 0, 'no summary, no request with auto generation off');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('off', 'Automatic generation off: adding a note leaves the issue without a summary');

// on, but only when a summary already exists: still nothing
ai.pluginSettings({ auto_generate: '1', auto_requires_existing_summary: '1' });
mark = ai.llmMark();
await addNote('Note with "requires existing summary" and no summary yet.');
await t.page.waitForTimeout(3000);
assert(summaryCount() === '0' && ai.llmRequests(mark).length === 0, 'nothing generated without an existing summary');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('requires-existing', 'Automatic generation on, "only when a summary exists": no summary yet, so the note triggers nothing');

// on: a note starts generation, the page polls the result in
ai.pluginSettings({ auto_generate: '1', auto_requires_existing_summary: '0' });
mark = ai.llmMark();
await addNote('Note that triggers a summary.');
await t.page.waitForSelector('#issue-summary[data-status="generating"]', { timeout: 3000 }).catch(() => {});
await t.page.waitForSelector('#issue-summary[data-status="up_to_date"]', { timeout: 20000 }).catch(() => {});
await t.page.waitForTimeout(300);
assert(await t.page.locator('#issue-summary').getAttribute('data-status') === 'up_to_date', 'auto generated summary shown');
const sent = ai.llmRequests(mark).filter(r => r.path.endsWith('/chat/completions'));
assert(sent.length === 1 && JSON.parse(sent[0].body.messages[1].content).notes.some(n => n.notes === 'Note that triggers a summary.'), 'the new note was sent');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('on', 'Automatic generation on: the note started a generation and the page polled the new summary in');

// on, requires existing, summary exists: regenerated
ai.pluginSettings({ auto_generate: '1', auto_requires_existing_summary: '1' });
mark = ai.llmMark();
await addNote('Second note, summary exists.');
await t.page.waitForSelector('#issue-summary[data-status="up_to_date"]', { timeout: 20000 }).catch(() => {});
await t.page.waitForTimeout(2500);
assert(ai.llmRequests(mark).filter(r => r.path.endsWith('/chat/completions')).length === 1, 'regenerated because a summary exists');
await t.go(`/issues/${id}`);
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('requires-existing-with-summary', '"Only when a summary exists" with a summary: the note regenerated it');

ai.pluginSettings();
await t.done();
