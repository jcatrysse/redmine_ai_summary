require_relative '../rails_helper'

RSpec.describe IssueSummary, type: :model do
  fixtures :issues, :users

  it 'validates summary presence when status is up to date' do
    summary = described_class.new(issue: issues(:issues_001), status: 'up_to_date')
    expect(summary).not_to be_valid
    expect(summary.errors[:summary]).to be_present
  end

  it 'allows blank summary when status is not up to date' do
    summary = described_class.new(issue: issues(:issues_001), status: 'generating')
    expect(summary).to be_valid
  end

  it 'identifies recent summaries' do
    summary = described_class.create!(
      issue: issues(:issues_001),
      status: 'up_to_date',
      summary: 'Done',
      updated_at: 2.days.ago
    )
    expect(summary.recent?).to be(true)
  end
end
