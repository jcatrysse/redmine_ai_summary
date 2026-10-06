# combination_view_issue_description-after

Run 2026-10-06T20:21:01.700Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](combination_view_issue_description-after-issue.png) | reporter | `/issues/1` | Reporter without view_issue_description: redmine_view_issue_description refuses the issue |
| ![](combination_view_issue_description-after-content.png) | reporter | `/issues/1/ai_summaries/content` | GET /issues/1/ai_summaries/content as the reporter: HTTP 403, summary text not shown |
| ![](combination_view_issue_description-after-manager.png) | manager | `/issues/1` | Manager (has view_issue_description): issue and summary shown as usual |
