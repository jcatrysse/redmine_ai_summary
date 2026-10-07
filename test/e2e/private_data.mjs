// Decision by Jan, 2026-10-07 (q1, option B): private notes and private subtasks
// are not sent to the provider and so never end up in the summary, which
// everyone who may see the issue can read. The fake LLM echoes the notes and
// subtasks it received, so each screenshot shows what was sent.
import { e2e } from '../../.codex/e2e/lib.mjs';
import ai from './support/ai.cjs';

const t = await e2e('private_data');
await ai.startLlm();
ai.pluginSettings();
ai.resetSummaries();
const id = ai.issueId('E2E issue with private data');
const privateSubtask = ai.issueId('E2E private subtask');
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };
const summaryText = () => t.page.locator('#issue-summary .wiki').innerText();

async function generate() {
  const mark = ai.llmMark();
  await t.go(`/issues/${id}`);
  await Promise.all([
    t.page.waitForResponse(r => r.request().method() === 'POST' && new URL(r.url()).pathname.endsWith('/ai_summaries')),
    t.page.click('#generate-summary-with-subtasks-button'),
  ]);
  await t.page.waitForTimeout(500);
  await t.page.waitForSelector('#issue-summary[data-status="up_to_date"]', { timeout: 20000 }).catch(() => {});
  await t.page.waitForTimeout(300);
  const sent = ai.llmRequests(mark).filter(r => r.path.endsWith('/chat/completions'));
  assert(sent.length === 1, `one request (${sent.length})`);
  const body = JSON.stringify(sent[0]?.body || {});
  assert(body.includes('PUBLIC NOTE') && body.includes('E2E public subtask'), 'public note and subtask sent');
  assert(!body.includes('PRIVATE NOTE') && !body.includes('E2E private subtask'), 'private note and subtask not sent');
}

// manager sees the private note and subtask in Redmine, but they are not sent
await t.login('manager');
t.page.on('dialog', d => d.accept());
await t.go(`/issues/${id}`);
assert(await t.page.getByText('PRIVATE NOTE for the team only').count() === 1, 'manager sees the private note');
await generate();
let text = await summaryText();
assert(text.includes('Notes received: "PUBLIC NOTE visible to everyone".') && text.includes('Subtasks received: "E2E public subtask".') && !text.includes('PRIVATE') && !text.includes('private subtask'), `manager summary: ${text}`);
await t.shot('manager', 'Manager sees the private note and the private subtask on the issue, yet the summary (generated with subtasks) received only the public note and the public subtask');

// admin: the same rule, also for someone who may see everything
await t.login('admin');
t.page.on('dialog', d => d.accept());
await generate();
text = await summaryText();
assert(text.includes('Notes received: "PUBLIC NOTE visible to everyone".') && text.includes('Subtasks received: "E2E public subtask".') && !text.includes('PRIVATE'), `admin summary: ${text}`);
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('admin', 'Admin generates: still only the public note and public subtask were sent');

// reporter: no view_private_notes; core hides the private note, the summary tells nothing more
await t.login('reporter');
await t.go(`/issues/${id}`);
assert(await t.page.getByText('PRIVATE NOTE for the team only').count() === 0, 'reporter does not see the private note');
text = await summaryText();
assert(!text.includes('PRIVATE') && !text.includes('private subtask'), `reporter summary: ${text}`);
assert(await t.page.locator('#generate-summary-button').count() === 0, 'reporter cannot generate');
let csrf = await t.page.locator('meta[name=csrf-token]').getAttribute('content');
let res = await t.page.request.post(`${t.BASE}/issues/${id}/ai_summaries`, { headers: { 'X-CSRF-Token': csrf, 'X-Requested-With': 'XMLHttpRequest' } });
assert(res.status() === 403, `reporter POST create: ${res.status()}`);
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('reporter', 'Reporter (no view_private_notes): the private note is hidden by core and the summary does not reveal it or the private subtask; generating is refused (403)');

// outsider: public project, so the issue and summary are readable, the private subtask is not
await t.login('outsider');
await t.go(`/issues/${id}`);
text = await summaryText();
assert(!text.includes('PRIVATE') && !text.includes('private subtask'), `outsider summary: ${text}`);
res = await t.page.request.get(`${t.BASE}/issues/${privateSubtask}/ai_summaries/content`);
assert(res.status() === 403, `outsider content of private subtask: ${res.status()}`);
csrf = await t.page.locator('meta[name=csrf-token]').getAttribute('content');
res = await t.page.request.post(`${t.BASE}/issues/${id}/ai_summaries`, { headers: { 'X-CSRF-Token': csrf, 'X-Requested-With': 'XMLHttpRequest' } });
assert(res.status() === 403, `outsider POST create: ${res.status()}`);
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('outsider', 'Outsider (no membership, public project): reads the summary, which holds no private data; the private subtask and generating are refused (403)');
await t.go(`/issues/${privateSubtask}`, { status: 403 });
await t.shot('outsider-private-subtask', 'Outsider: the private subtask itself is refused (403)');

await t.done();
