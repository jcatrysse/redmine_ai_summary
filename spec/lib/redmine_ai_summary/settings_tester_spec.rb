require_relative '../../rails_helper'

RSpec.describe RedmineAiSummary::SettingsTester do
  it 'fails tests when the API key is missing' do
    allow(Setting).to receive(:plugin_redmine_ai_summary).and_return(
      'api_key' => '',
      'api_endpoint' => '',
      'model' => ''
    )

    result = described_class.test_connection

    expect(result[:success]).to be(false)
    expect(result[:message]).to eq('API key is missing')
  end

  it 'normalizes OpenAI-compatible base URLs without duplicating v1' do
    allow(Setting).to receive(:plugin_redmine_ai_summary).and_return(
      'api_key' => 'token',
      'api_endpoint' => 'https://api.example.com/openai/v1',
      'model' => 'model'
    )

    config = described_class.api_config

    expect(config[:base_url]).to eq('https://api.example.com/openai/v1')
  end
end
