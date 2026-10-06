# auto_generate

Run 2026-10-06T19:50:39.494Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](auto_generate-off.png) | manager | `/issues/2` | Automatic generation off: adding a note leaves the issue without a summary |
| ![](auto_generate-requires-existing.png) | manager | `/issues/2` | Automatic generation on, "only when a summary exists": no summary yet, so the note triggers nothing |
| ![](auto_generate-on.png) | manager | `/issues/2` | Automatic generation on: the note started a generation and the page polled the new summary in |
| ![](auto_generate-requires-existing-with-summary.png) | manager | `/issues/2` | "Only when a summary exists" with a summary: the note regenerated it |
