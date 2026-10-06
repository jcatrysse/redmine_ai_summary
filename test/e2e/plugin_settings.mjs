// The global plugin settings (admin only): the form, saving with the masked
// API key, invalid model parameters JSON, the connection test and the model
// list (against the fake LLM), and the refusals for a non-admin.
import { e2e } from '../../.codex/e2e/lib.mjs';
import ai from './support/ai.cjs';

const t = await e2e('plugin_settings');
await ai.startLlm();
ai.pluginSettings();
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };
const stored = key => ai.rails(`print Setting.plugin_redmine_ai_summary[ENV['K']]`, { K: key });
const URL = '/settings/plugin/redmine_ai_summary';

await t.login('admin');
t.page.on('dialog', d => d.accept());
await t.go(URL);
await t.sudo();
assert(await t.page.locator('#settings_api_endpoint').inputValue() === ai.ENDPOINT, 'endpoint shown');
assert(await t.page.locator('#settings_api_key').inputValue() === '*'.repeat(32), `key is masked: ${await t.page.locator('#settings_api_key').inputValue()}`);
await t.shot('form', 'Plugin settings as admin: endpoint, masked API key, model, model parameters JSON, the API tools, prompt and options');

// connection test and model list against the fake LLM
await t.page.click('#ai-summary-test-connection');
await t.page.waitForSelector('#ai-summary-api-result.notice', { timeout: 10000 }).catch(() => {});
assert(await t.page.locator('#ai-summary-api-result.notice').count() === 1, `test connection ok: ${await t.page.locator('#ai-summary-api-result').innerText()}`);
await t.page.click('#ai-summary-list-models');
await t.page.waitForSelector('#ai-summary-models li', { timeout: 10000 }).catch(() => {});
const models = await t.page.locator('#ai-summary-models li').allInnerTexts();
assert(models.includes('e2e-model'), `models listed: ${models}`);
t.check('api tools');
await t.page.locator('#ai-summary-api-result').scrollIntoViewIfNeeded();
await t.shot('api-tools', `Test connection succeeded and List models shows the provider's models (${models.join(', ')})`);

// save with the masked key untouched: the stored key is kept
await t.page.fill('#settings_model', 'e2e-model-saved');
await t.page.locator('#settings input[type=submit], form input[type=submit][name=commit]').first().click();
await t.settle();
await t.sudo();
t.check('save');
assert(stored('model') === 'e2e-model-saved', `model saved: ${stored('model')}`);
assert(stored('api_key') === 'e2e-key', `masked key kept the stored key: ${stored('api_key')}`);
await t.shot('saved', 'Saved with the masked key untouched: "Successful update", the new model is stored and the API key is unchanged');

// invalid model parameters JSON: refused with a message, nothing stored
await t.go(URL);
await t.page.fill('#settings_model_parameters_json', '{not json');
await t.page.fill('#settings_model', 'should-not-be-saved');
await t.page.locator('#settings input[type=submit], form input[type=submit][name=commit]').first().click();
await t.settle();
await t.sudo();
t.check('save invalid');
assert(await t.page.locator('#flash_error').count() === 1, 'error flash for invalid JSON');
assert(stored('model') === 'e2e-model-saved' && stored('model_parameters_json') !== '{not json', 'nothing saved on invalid JSON');
await t.shot('invalid-json', 'Invalid model parameters JSON: refused with an error message, the stored settings are unchanged');

// connection test without a key: an error, no request
ai.pluginSettings({ api_key: '' });
const mark = ai.llmMark();
await t.go(URL);
await t.page.click('#ai-summary-test-connection');
await t.page.waitForSelector('#ai-summary-api-result.error', { timeout: 10000 }).catch(() => {});
assert((await t.page.locator('#ai-summary-api-result').innerText()).includes('API key is missing'), 'missing key message');
assert(ai.llmRequests(mark).length === 0, 'no request without a key');
t.check('test without key', { requests: ['422 fetch /ai_summary_settings/test'] });
await t.page.locator('#ai-summary-api-result').scrollIntoViewIfNeeded();
await t.shot('test-no-key', 'Test connection without an API key: "API key is missing", nothing sent');
ai.pluginSettings();

// non-admin: the page and the API tools are refused
await t.login('manager');
await t.go(URL, { status: 403 });
await t.shot('manager-refused', 'Manager (not admin): the plugin settings page is refused (403)');
const res = await t.page.request.get(`${t.BASE}/ai_summary_settings/models`);
assert(res.status() === 403, `manager GET models: ${res.status()}`);

await t.done();
