require_relative '../rails_helper'

RSpec.describe GenerateSummaryJob, type: :job do
  fixtures :issues, :users

  let(:issue) { issues(:issues_001) }
  let(:user) { users(:users_001) }

  before do
    allow(Issue).to receive(:find_by).with(id: issue.id).and_return(issue)
    allow(User).to receive(:find_by).with(id: user.id).and_return(user)
  end

  it 'keeps debug payload in error_message when debug logging is enabled' do
    summary = IssueSummary.create!(
      issue: issue,
      status: 'generating',
      summary: 'Old summary',
      error_message: '{"request":"payload"}'
    )

    allow(RedmineAiSummary::SummaryGenerator).to receive(:generate)
      .and_return([true, summary, nil])
    allow(RedmineAiSummary::SettingsResolver).to receive(:debug_logging_enabled?)
      .with(issue.project)
      .and_return(true)

    described_class.perform_now(issue.id, user.id)

    summary.reload
    expect(summary.status).to eq('up_to_date')
    expect(summary.error_message).to eq('{"request":"payload"}')
  end

  it 'clears error_message on success when debug logging is disabled' do
    summary = IssueSummary.create!(
      issue: issue,
      status: 'generating',
      summary: 'Old summary',
      error_message: '{"request":"payload"}'
    )

    allow(RedmineAiSummary::SummaryGenerator).to receive(:generate)
      .and_return([true, summary, nil])
    allow(RedmineAiSummary::SettingsResolver).to receive(:debug_logging_enabled?)
      .with(issue.project)
      .and_return(false)

    described_class.perform_now(issue.id, user.id)

    summary.reload
    expect(summary.status).to eq('up_to_date')
    expect(summary.error_message).to be_nil
  end
end
