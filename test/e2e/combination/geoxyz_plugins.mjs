// Combination check with the other GEOxyz plugins installed (their
// redmine70-migration branches): Project > Settings with the AI summary tab,
// the issue list and an issue page with the summary block answer 200.
// Runs only with RMP_COMBINATION=1; other plugins change what reporter and
// outsider may see, so only HTTP status and the plugin's own elements count.
import { e2e } from '../../../.codex/e2e/lib.mjs';
import ai from '../support/ai.cjs';

if (process.env.RMP_COMBINATION !== '1') {
  console.log('combination_geoxyz_plugins: RMP_COMBINATION is not 1, nothing to check');
  process.exit(0);
}
const t = await e2e(`combination_geoxyz_plugins-${process.env.LABEL || 'run'}`);
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };
const id = ai.issueId('E2E assigned issue');
// Other plugins' JS errors and missing assets are not this plugin's business:
// only HTTP status and this plugin's elements count here.
const allow = { js: [''], requests: [''] };
async function login(user) {
  const page = await t.anonymous();
  await page.goto(`${t.BASE}/login`);
  await page.fill('#username', user);
  await page.fill('#password', process.env.RMP_USER_PASSWORD || process.env.RMP_ADMIN_PASSWORD || 'Redmine7Test!');
  await page.click('#login-submit');
  await page.waitForURL(u => !u.pathname.startsWith('/login'), { timeout: 20000 }).catch(() => {});
  t.check(`login ${user}`, allow);
}

for (const user of ['admin', 'manager']) {
  await login(user);
  await t.go('/projects/e2e-project/settings', { allow });
  await t.go('/projects/e2e-project/settings/ai_summary', { allow });
  assert(await t.page.locator('#tab-ai_summary').count() === 1, `${user}: AI summary tab present`);
  await t.shot(`${user}-project-settings`, `${user}: Project > Settings answers 200 with the other GEOxyz plugins, AI summary tab shown`);
  await t.go('/projects/e2e-project/issues', { allow });
  await t.shot(`${user}-issue-list`, `${user}: the issue list answers 200`);
  await t.go(`/issues/${id}`, { allow });
  assert(await t.page.locator('#issue-summary-container').count() === 1, `${user}: summary block on the issue page`);
  await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded().catch(() => {});
  await t.shot(`${user}-issue`, `${user}: the issue page answers 200 with the AI summary block`);
}
await login('reporter');
await t.go('/projects/e2e-project/settings', { status: 403, allow });
await t.go('/projects/e2e-project/issues', { allow });
await t.go(`/issues/${id}/ai_summaries/content`, { status: process.env.EXPECT_REPORTER_CONTENT ? Number(process.env.EXPECT_REPORTER_CONTENT) : 403, allow });
await t.go('/projects/e2e-project/issues', { allow });
await t.shot('reporter-issue-list', 'reporter: project settings refused (403), the issue list answers 200; the summary of an issue redmine_view_issue_description refuses to them is refused too (403)');
await login('outsider');
await t.go('/projects/e2e-private/settings/ai_summary', { status: 403, allow });
await t.shot('outsider-private-settings', 'outsider: settings of the private project refused (403)');
await t.done();
