# project_settings

Run 2026-10-06T20:44:57.940Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](project_settings-tab.png) | manager | `/projects/e2e-project/settings/ai_summary` | Manager: project settings render again with the module on; the AI summary tab, every field on "inherit" with the global value as placeholder |
| ![](project_settings-saved.png) | manager | `/projects/e2e-project/settings/ai_summary` | Overrides saved: the model shows e2e-empty, the project API key is masked |
| ![](project_settings-override-used.png) | manager | `/issues/4` | Generation in this project used the project model (e2e-empty): the fake provider answered empty content |
| ![](project_settings-invalid-json.png) | manager | `/projects/e2e-project/settings/ai_summary` | Invalid model parameters JSON in the project: refused with an error message, nothing stored |
| ![](project_settings-inherit.png) | manager | `/issues/4` | Overrides cleared ("inherit"): generation uses the global model again and succeeds |
| ![](project_settings-reporter.png) | reporter | `/projects/e2e-project` | Reporter (no manage permission): the project page shows no Settings tab; PUT to the AI summary settings answers 403 |
| ![](project_settings-outsider.png) | outsider | `/projects/e2e-private/settings/ai_summary` | Outsider: the private project settings are refused (403) |
