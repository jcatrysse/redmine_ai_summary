// What a user does with a summary: quote it into a note, copy it, see it go
// stale when the issue changes and regenerate it, delete it.
import { e2e } from '../../.codex/e2e/lib.mjs';
import ai from './support/ai.cjs';

const t = await e2e('summary_actions');
await ai.startLlm();
ai.pluginSettings();
ai.resetSummaries();
const id = ai.issueId('E2E related issue');
const assert = (ok, what) => { if (!ok) t.problems.push(`assert: ${what}`); };
const status = () => t.page.locator('#issue-summary').getAttribute('data-status');
async function waitForStatus(s, timeout = 20000) {
  await t.page.waitForSelector(`#issue-summary[data-status="${s}"]`, { timeout }).catch(() => {});
  return status();
}

await t.login('manager');
await t.page.context().grantPermissions(['clipboard-read', 'clipboard-write'], { origin: t.BASE });
t.page.on('dialog', d => d.accept());
await t.go(`/issues/${id}`);
await t.page.click('#generate-summary-button');
assert(await waitForStatus('up_to_date') === 'up_to_date', 'generated');
await t.page.waitForTimeout(300);
const summaryText = 'Fake summary* of "E2E related issue"';
const notesIn = async () => Number(((await t.page.locator('#issue-summary .wiki').innerText()).match(/(\d+) note\(s\)/) || [])[1]);
const notesBefore = await notesIn();

// quote into the notes editor
await t.page.locator('#issue-summary a[data-action=quote]').click();
await t.page.waitForTimeout(500);
const notes = await t.page.locator('#issue_notes').inputValue();
assert(notes.startsWith('> *Fake summary*') && notes.includes(summaryText), `quoted notes: ${notes}`);
await t.page.locator('#issue_notes').scrollIntoViewIfNeeded();
await t.shot('quoted', 'Quote Summary opened the edit form and put the summary, quoted with "> ", into the notes');

// copy to the clipboard
await t.go(`/issues/${id}`);
await t.page.locator('#issue-summary a[data-action=copy]').click();
await t.page.waitForSelector('#summary-notice.notice', { timeout: 3000 }).catch(() => {});
const clip = await t.page.evaluate(() => navigator.clipboard.readText());
assert(clip.includes(summaryText), `clipboard: ${clip}`);
assert((await t.page.locator('#summary-notice').innerText()).length > 0, 'copy notice shown');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('copied', 'Copy Summary put the summary on the clipboard and shows a short notice');

// any change to the issue makes the summary stale
await t.page.locator('.contextual a.icon-edit').first().click();
await t.page.fill('#issue_notes', 'A change after the summary.');
await t.page.locator('#issue-form input[type=submit][name=commit]').first().click();
await t.settle();
t.check('add note');
assert(await status() === 'stale', `stale after a note (got ${await status()})`);
assert(await t.page.locator('#regenerate-summary-button svg use').count() === 1, 'regenerate button with icon');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('stale', 'After a note the summary is marked stale, with Regenerate and Regenerate (with subtasks)');

// regenerate (no confirmation on this one)
await t.page.click('#regenerate-summary-button');
assert(await waitForStatus('up_to_date') === 'up_to_date', 'regenerated');
await t.page.waitForTimeout(300);
assert(await notesIn() === notesBefore + 1, `regenerated summary counts the new note (${notesBefore} -> ${await notesIn()})`);
assert(await t.page.locator('#issue-summary .warning').count() === 0, 'no stale warning after regenerate');
await t.shot('regenerated', 'Regenerate produced a fresh summary; the stale warning is gone');

// delete, with confirmation, back to the empty state
await t.page.locator('#issue-summary a.icon-del').click();
await t.page.waitForSelector('#issue-summary[data-status="new"]', { timeout: 5000 }).catch(() => {});
assert(await status() === 'new', 'deleted');
assert(ai.rails(`print IssueSummary.where(issue_id: ${id}).count`) === '0', 'summary row gone');
await t.page.locator('#issue-summary-container').scrollIntoViewIfNeeded();
await t.shot('deleted', 'Reset Summary (after the confirmation) deleted the summary: back to "No summary available yet."');

await t.done();
