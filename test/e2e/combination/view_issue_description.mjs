// Combination check with redmine_view_issue_description: a member without
// view_issue_description may not open an issue; the AI summary of it must
// not be readable either. Runs only when that plugin is installed next to
// this one (plugins/redmine_view_issue_description); otherwise there is
// nothing to check and it says so.
import fs from 'node:fs';
import path from 'node:path';
import { e2e } from '../../../.codex/e2e/lib.mjs';
import ai from '../support/ai.cjs';

const other = path.join(process.env.REDMINE_DIR || 'redmine', 'plugins', 'redmine_view_issue_description');
if (!fs.existsSync(other)) {
  console.log('combination_view_issue_description: redmine_view_issue_description not installed, nothing to check');
  process.exit(0);
}

const label = process.env.LABEL || 'after';
const t = await e2e(`combination_view_issue_description-${label}`);
const id = ai.issueId('E2E assigned issue');
ai.rails(`IssueSummary.where(issue_id: ${id}).delete_all; IssueSummary.create!(issue_id: ${id}, summary: 'Summary of a description the reporter may not see', status: 'up_to_date')`);
await t.login('reporter');
await t.go(`/issues/${id}`, { status: 403 });
await t.shot('issue', 'Reporter without view_issue_description: redmine_view_issue_description refuses the issue');
const res = await t.page.request.get(`${t.BASE}/issues/${id}/ai_summaries/content`);
const body = await res.text();
const leaked = body.includes('Summary of a description the reporter may not see');
console.log(`content endpoint: HTTP ${res.status()}, summary in body: ${leaked}`);
await t.go(`/issues/${id}/ai_summaries/content`, { status: Number(process.env.EXPECT || 403) });
await t.shot('content', `GET /issues/${id}/ai_summaries/content as the reporter: HTTP ${res.status()}, summary text ${leaked ? 'LEAKED' : 'not shown'}`);
await t.login('manager');
await t.go(`/issues/${id}`);
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('manager', 'Manager (has view_issue_description): issue and summary shown as usual');
await t.done();
