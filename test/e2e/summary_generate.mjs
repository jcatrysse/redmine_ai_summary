// Generating an issue summary by hand (with and without subtasks), seeing it,
// and who may: manager (every permission), reporter (view only, the public
// permission), outsider, anonymous, and the private issue the reporter cannot see.
import { e2e } from '../../.codex/e2e/lib.mjs';
import ai from './support/ai.cjs';

const t = await e2e('summary_generate');
await ai.startLlm();
ai.pluginSettings();
ai.resetSummaries();
const parent = ai.issueId('E2E assigned issue');
const plain = ai.issueId('E2E unassigned issue');
const privateIssue = ai.issueId('E2E private issue in public project');
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };

async function waitForStatus(status, timeout = 20000) {
  await t.page.waitForSelector(`#issue-summary[data-status="${status}"]`, { timeout }).catch(() => {});
  return t.page.locator('#issue-summary').getAttribute('data-status');
}

// manager: empty state, buttons with icons
await t.login('manager');
t.page.on('dialog', d => d.accept());
await t.go(`/issues/${parent}`);
assert(await t.page.locator('#issue-summary').getByText('No summary available yet.').count() === 1, 'empty state shown');
assert(await t.page.locator('#generate-summary-button svg use').count() === 1, 'generate button has an SVG icon');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('manager-empty', 'Manager, no summary yet: the empty state and both generate buttons, each with its SVG icon');

// manager: generate, the "generating" state, then the polled result
let mark = ai.llmMark();
await t.page.click('#generate-summary-button');
await waitForStatus('generating', 5000);
await t.shot('manager-generating', 'Manager clicked Generate Summary: the block shows that the summary is being generated');
let status = await waitForStatus('up_to_date');
assert(status === 'up_to_date', `summary up to date after polling (got ${status})`);
await t.page.waitForTimeout(300);
const text = await t.page.locator('#issue-summary .wiki').innerText();
assert(text.includes('Fake summary') && text.includes('0 subtask(s)'), `summary text without subtasks: ${text}`);
let reqs = ai.llmRequests(mark).filter(r => r.path.endsWith('/chat/completions'));
assert(reqs.length === 1 && reqs[0].auth === 'Bearer e2e-key', 'one chat request with the key');
assert(reqs[0] && JSON.parse(reqs[0].body.messages[1].content).subtasks === undefined, 'no subtasks sent');
t.check('generate');
await t.shot('manager-generated', 'Polling replaced the block with the generated summary (rendered as wiki text), the "updated by" line and the quote, copy and delete actions');

// manager: with subtasks
mark = ai.llmMark();
await t.page.click('#generate-summary-with-subtasks-button');
await waitForStatus('generating', 5000);
status = await waitForStatus('up_to_date');
await t.page.waitForTimeout(300);
const withSubtasks = await t.page.locator('#issue-summary .wiki').innerText();
assert(withSubtasks.includes('1 subtask(s)'), `summary with subtasks: ${withSubtasks}`);
reqs = ai.llmRequests(mark).filter(r => r.path.endsWith('/chat/completions'));
assert(reqs.length === 1 && JSON.parse(reqs[0].body.messages[1].content).subtasks?.[0]?.subject === 'E2E subtask', 'subtask sent');
await t.shot('manager-with-subtasks', 'Generate Summary (with subtasks): the request carried the subtask, the summary counts 1 subtask');

// subtask depth 0: the subtask button disappears
ai.pluginSettings({ subtask_summary_max_depth: '0' });
await t.go(`/issues/${plain}`);
assert(await t.page.locator('#generate-summary-button').count() === 1, 'generate button with depth 0');
assert(await t.page.locator('#generate-summary-with-subtasks-button').count() === 0, 'no subtask button with depth 0');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('manager-depth-zero', 'Subtask depth 0 in the plugin settings: only Generate Summary is offered');
ai.pluginSettings();

// reporter: sees the existing summary (public view permission), no actions
await t.login('reporter');
await t.go(`/issues/${parent}`);
assert(await t.page.locator('#issue-summary .wiki').count() === 1, 'reporter sees the summary');
assert(await t.page.locator('#generate-summary-button, #generate-summary-with-subtasks-button, #issue-summary a.icon-del').count() === 0, 'reporter has no generate or delete');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('reporter-view-only', 'Reporter (no plugin permissions): sees the summary through the public view permission, no generate or delete actions');

// reporter: no summary yet and no generate permission -> no block at all
await t.go(`/issues/${plain}`);
assert(await t.page.locator('#issue-summary-container').count() === 0, 'no block for reporter without summary');
await t.shot('reporter-no-block', 'Reporter on an issue without a summary: nothing to show and nothing allowed, so no summary block');

// reporter: refused by the server too
let csrf = await t.page.locator('meta[name=csrf-token]').getAttribute('content');
let res = await t.page.request.post(`${t.BASE}/issues/${plain}/ai_summaries`, { headers: { 'X-CSRF-Token': csrf, 'X-Requested-With': 'XMLHttpRequest', Accept: 'text/javascript' } });
assert(res.status() === 403, `reporter POST create: ${res.status()}`);
const sid = ai.rails(`print IssueSummary.find_by!(issue_id: ${parent}).id`);
res = await t.page.request.delete(`${t.BASE}/issues/${parent}/ai_summaries/${sid}`, { headers: { 'X-CSRF-Token': csrf, 'X-Requested-With': 'XMLHttpRequest', Accept: 'text/javascript' } });
assert(res.status() === 403, `reporter DELETE: ${res.status()}`);
assert(ai.rails(`print IssueSummary.where(id: ${sid}).count`) === '1', 'summary still there');

// reporter: private issue in the public project -> the issue and its summary are refused
ai.rails(`IssueSummary.create!(issue_id: ${privateIssue}, summary: 'Private summary text', status: 'up_to_date')`);
await t.go(`/issues/${privateIssue}`, { status: 403 });
await t.shot('reporter-private-issue', 'Reporter on a private issue of the public project: core refuses the issue (403)');
res = await t.page.request.get(`${t.BASE}/issues/${privateIssue}/ai_summaries/content`);
const body = await res.text();
assert(res.status() === 403 && !body.includes('Private summary text'), `reporter GET content of private issue: ${res.status()}`);

// anonymous: same, the summary endpoint does not leak the private issue
await t.anonymous();
res = await t.page.request.get(`${t.BASE}/issues/${privateIssue}/ai_summaries/content`);
assert(res.status() === 403 && !(await res.text()).includes('Private summary text'), `anonymous GET content of private issue: ${res.status()}`);
await t.go(`/issues/${parent}`);
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded().catch(() => {});
await t.shot('anonymous-public-issue', 'Anonymous on a public issue: the summary is readable (public view permission), no actions');

// outsider: the private project and its issues stay invisible
await t.login('outsider');
const hidden = ai.issueId('E2E private issue');
await t.go(`/issues/${hidden}`, { status: 403 });
res = await t.page.request.get(`${t.BASE}/issues/${hidden}/ai_summaries/content`);
assert(res.status() === 403, `outsider GET content in private project: ${res.status()}`);
await t.shot('outsider-private-project', 'Outsider: an issue of the private project and its summary endpoint are refused (403)');

// module disabled: no block, even for the manager
ai.rails(`p = Project.find_by!(identifier: 'e2e-project'); p.enabled_module_names = p.enabled_module_names - ['ai_summary']; p.save!`);
await t.login('manager');
await t.go(`/issues/${parent}`);
assert(await t.page.locator('#issue-summary-container').count() === 0, 'no block with the module disabled');
res = await t.page.request.get(`${t.BASE}/issues/${parent}/ai_summaries/content`);
assert(res.status() === 403, `content with module disabled: ${res.status()}`);
await t.shot('module-disabled', 'AI summary module disabled in the project: no summary block, and the content endpoint answers 403');
ai.rails(`p = Project.find_by!(identifier: 'e2e-project'); p.enabled_module_names = p.enabled_module_names + ['ai_summary']; p.save!`);

await t.done();
