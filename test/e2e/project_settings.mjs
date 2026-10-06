// The project's AI summary tab (manage_ai_summary_settings): every project
// settings tab renders again with the module on (it was HTTP 500), overrides
// are saved and used, the masked project key is kept, invalid JSON is refused,
// "inherit" falls back to the global settings; refusals without the permission.
import { e2e } from '../../.codex/e2e/lib.mjs';
import ai from './support/ai.cjs';

const t = await e2e('project_settings');
await ai.startLlm();
ai.pluginSettings();
ai.resetSummaries();
const id = ai.issueId('E2E related issue');
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };
const override = f => ai.rails(`s = AiSummaryProjectSetting.find_by(project: Project.find_by!(identifier: 'e2e-project')); print s ? s.read_attribute(ENV['F']).inspect : 'none'`, { F: f });
const TAB = '/projects/e2e-project/settings/ai_summary';
const save = async () => {
  await t.page.locator('#tab-content-ai_summary input[type=submit]').click();
  await t.settle();
  t.check('save project settings');
};

await t.login('manager');
t.page.on('dialog', d => d.accept());

// every settings tab renders with the module enabled
for (const tab of ['info', 'modules', 'members', 'issues', 'versions']) {
  await t.go(`/projects/e2e-project/settings/${tab}`);
}
await t.go(TAB);
assert(await t.page.locator('#tab-ai_summary').count() === 1, 'AI summary tab present');
await t.shot('tab', 'Manager: project settings render again with the module on; the AI summary tab, every field on "inherit" with the global value as placeholder');

// override the model and the key; the override is used for generation
await t.page.fill('#ai_summary_settings_model', 'e2e-empty');
await t.page.fill('#ai_summary_settings_api_key', 'e2e-key');
await save();
assert(override('model') === '"e2e-empty"' && override('api_key') === '"e2e-key"', `override saved: ${override('model')}`);
await t.go(TAB);
assert(await t.page.locator('#ai_summary_settings_api_key').inputValue() === '*'.repeat(32), 'project key masked');
await t.shot('saved', 'Overrides saved: the model shows e2e-empty, the project API key is masked');

await t.go(`/issues/${id}`);
await Promise.all([
  t.page.waitForResponse(r => r.request().method() === 'POST' && r.url().endsWith('/ai_summaries')),
  t.page.click('#generate-summary-button'),
]);
await t.page.waitForTimeout(500);
await t.page.waitForSelector('#issue-summary[data-status="stale"]', { timeout: 20000 }).catch(() => {});
assert(await t.page.locator('#issue-summary [data-action=copy_error]').getAttribute('data-error-message') === 'AI Summary returned empty content', 'the project model override was used');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('override-used', 'Generation in this project used the project model (e2e-empty): the fake provider answered empty content');

// saving again with the masked key keeps the project key
await t.go(TAB);
await t.page.fill('#ai_summary_settings_subtask_summary_max_depth', '1');
await save();
assert(override('api_key') === '"e2e-key"' && override('subtask_summary_max_depth') === '1', `masked key kept: ${override('api_key')}`);

// invalid JSON: refused with a message
await t.go(TAB);
await t.page.fill('#ai_summary_settings_model_parameters_json', '[1, 2');
await save();
assert(await t.page.locator('#flash_error').count() === 1, 'error flash for invalid JSON');
assert(override('model_parameters_json') === 'nil', `invalid JSON not stored: ${override('model_parameters_json')}`);
await t.shot('invalid-json', 'Invalid model parameters JSON in the project: refused with an error message, nothing stored');

// back to inherit: the global settings apply again
await t.go(TAB);
await t.page.fill('#ai_summary_settings_model', '');
await t.page.fill('#ai_summary_settings_api_key', '');
await t.page.fill('#ai_summary_settings_subtask_summary_max_depth', '');
await save();
assert(override('model') === 'nil' && override('api_key') === 'nil', 'overrides cleared');
await t.go(`/issues/${id}`);
await Promise.all([
  t.page.waitForResponse(r => r.request().method() === 'POST' && r.url().endsWith('/ai_summaries')),
  t.page.click('#generate-summary-button'),
]);
await t.page.waitForTimeout(500);
await t.page.waitForSelector('#issue-summary[data-status="up_to_date"]', { timeout: 20000 }).catch(() => {});
assert(await t.page.locator('#issue-summary').getAttribute('data-status') === 'up_to_date', 'global model used again');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('inherit', 'Overrides cleared ("inherit"): generation uses the global model again and succeeds');

// reporter: no project settings, and the update is refused
await t.login('reporter');
await t.go('/projects/e2e-project/settings', { status: 403 });
await t.go('/projects/e2e-project');
const csrf = await t.page.locator('meta[name=csrf-token]').getAttribute('content');
const res = await t.page.request.put(`${t.BASE}/projects/e2e-project/ai_summary_settings`, {
  headers: { 'X-CSRF-Token': csrf }, form: { 'ai_summary_settings[model]': 'hijack' }, maxRedirects: 0,
});
assert(res.status() === 403, `reporter PUT: ${res.status()}`);
assert(override('model') === 'nil', 'reporter changed nothing');
await t.shot('reporter', 'Reporter (no manage permission): the project page shows no Settings tab; PUT to the AI summary settings answers 403');

// outsider: the private project does not exist for them
await t.login('outsider');
await t.go('/projects/e2e-private/settings/ai_summary', { status: 403 });
await t.shot('outsider', 'Outsider: the private project settings are refused (403)');

ai.resetSummaries();
await t.done();
