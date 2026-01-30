require_relative '../../rails_helper'

RSpec.describe RedmineAiSummary::SummaryGenerator do
  fixtures :issues, :users

  let(:issue) { issues(:issues_001) }
  let(:user) { users(:users_001) }
  let(:client) { instance_double(OpenAI::Client) }

  before do
    allow(issue).to receive(:changesets).and_return([])
    allow(issue).to receive(:journals).and_return([])
    allow(Setting).to receive(:text_formatting).and_return('textile')
    allow(RedmineAiSummary::SettingsResolver).to receive(:debug_logging_enabled?).and_return(true)
    allow(RedmineAiSummary::SettingsResolver).to receive(:model).and_return('gpt-test')
    allow(RedmineAiSummary::SettingsResolver).to receive(:system_prompt).and_return('Prompt')
    allow(RedmineAiSummary::SettingsResolver).to receive(:model_parameters).and_return({ max_completion_tokens: 20 })
    allow(RedmineAiSummary::SettingsResolver).to receive(:api_endpoint).and_return('')
    allow(RedmineAiSummary::SettingsResolver).to receive(:api_key).and_return('token')
    allow(OpenAI::Client).to receive(:new).and_return(client)
  end

  it 'stores request/response payload in error_message when debug logging is enabled' do
    response = {
      'choices' => [
        { 'message' => { 'content' => 'Summary' }, 'finish_reason' => 'stop' }
      ]
    }
    allow(client).to receive(:chat).and_return(response)

    success, summary, _error = described_class.generate(issue, user)

    expect(success).to be(true)
    expect(summary).to be_present
    payload = JSON.parse(summary.error_message)
    expect(payload['request']).to be_present
    expect(payload['response']).to eq(response)
  end

  it 'passes model parameters into the API request' do
    response = {
      'choices' => [
        { 'message' => { 'content' => 'Summary' }, 'finish_reason' => 'stop' }
      ]
    }
    allow(RedmineAiSummary::SettingsResolver).to receive(:model_parameters).and_return(
      { max_completion_tokens: 5, temperature: 0.2 }
    )

    expect(client).to receive(:chat).with(
      parameters: hash_including(
        model: 'gpt-test',
        max_completion_tokens: 5,
        temperature: 0.2
      )
    ).and_return(response)

    described_class.generate(issue, user)
  end
end
