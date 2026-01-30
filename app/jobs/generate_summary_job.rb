class GenerateSummaryJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id, user_id, subtask_max_depth = nil)
    RedmineAiSummary::SettingsResolver.reload!
    issue = Issue.find_by(id: issue_id)
    user = User.find_by(id: user_id)
    return unless issue && user

    summary = IssueSummary.find_or_initialize_by(issue_id: issue.id)
    summary.status = 'generating'
    summary.save!

    begin
      success, generated_summary, error_message = RedmineAiSummary::SummaryGenerator.generate(
        issue,
        user,
        subtask_max_depth: subtask_max_depth
      )

      if success
        error_message = if RedmineAiSummary::SettingsResolver.debug_logging_enabled?(issue.project)
                          summary.reload.error_message
                        end
        summary.reload.update(
          status: 'up_to_date',
          error_message: error_message,
          summary: generated_summary&.summary || summary.summary
        )
      else
        summary.reload.update(status: 'stale', error_message: error_message)
      end
    rescue StandardError => e
      Rails.logger.error "AI Summary job failed for issue ##{issue_id}: #{e.message}"
      summary.reload.update(status: 'stale', error_message: e.message) if summary.persisted?
    end
  end
end
