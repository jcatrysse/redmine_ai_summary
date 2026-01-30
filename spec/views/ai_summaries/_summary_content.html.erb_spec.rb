require_relative '../../rails_helper'

RSpec.describe 'ai_summaries/_summary_content.html.erb', type: :view do
  fixtures :issues, :users, :projects

  it 'marks the error icon as a copy action when an error message exists' do
    issue = issues(:issues_001)
    User.current = users(:users_001)
    summary = IssueSummary.create!(
      issue: issue,
      status: 'stale',
      summary: 'Summary text',
      error_message: 'API error'
    )

    render partial: 'ai_summaries/summary_content', locals: { issue: issue, summary: summary }

    expect(rendered).to include('data-action="copy_error"')
    expect(rendered).to include('data-error-message="API error"')
  ensure
    User.current = nil
  end

  it 'does not render the error copy action when no error message exists' do
    issue = issues(:issues_001)
    User.current = users(:users_001)
    summary = IssueSummary.create!(
      issue: issue,
      status: 'up_to_date',
      summary: 'Summary text',
      error_message: nil
    )

    render partial: 'ai_summaries/summary_content', locals: { issue: issue, summary: summary }

    expect(rendered).not_to include('data-action="copy_error"')
  ensure
    User.current = nil
  end

  it 'escapes error messages in the copy data attribute' do
    issue = issues(:issues_001)
    User.current = users(:users_001)
    summary = IssueSummary.create!(
      issue: issue,
      status: 'stale',
      summary: 'Summary text',
      error_message: 'Bad "quote"'
    )

    render partial: 'ai_summaries/summary_content', locals: { issue: issue, summary: summary }

    expect(rendered).to include('data-error-message="Bad &quot;quote&quot;"')
  ensure
    User.current = nil
  end
end
