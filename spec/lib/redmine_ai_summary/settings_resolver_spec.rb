require_relative '../../rails_helper'

RSpec.describe RedmineAiSummary::SettingsResolver do
  describe '.model_parameters' do
    it 'parses JSON into symbolized parameters' do
      allow(Setting).to receive(:plugin_redmine_ai_summary).and_return(
        { 'model_parameters_json' => '{"max_completion_tokens":800,"temperature":0.2}' }
      )

      expect(described_class.model_parameters).to eq(
        { max_completion_tokens: 800, temperature: 0.2 }
      )
    end

    it 'falls back to max_completion_tokens when JSON is blank' do
      allow(Setting).to receive(:plugin_redmine_ai_summary).and_return(
        { 'model_parameters_json' => '', 'max_completion_tokens' => 123 }
      )

      expect(described_class.model_parameters).to eq({ max_completion_tokens: 123 })
    end

    it 'returns empty hash and warns when JSON is invalid and no fallback is set' do
      allow(Setting).to receive(:plugin_redmine_ai_summary).and_return(
        { 'model_parameters_json' => '{bad json', 'max_completion_tokens' => nil }
      )
      allow(Rails.logger).to receive(:warn)

      expect(described_class.model_parameters).to eq({})
      expect(Rails.logger).to have_received(:warn).with(/model parameters JSON invalid/)
    end

    it 'prefers max_completion_tokens when both token keys are provided' do
      allow(Setting).to receive(:plugin_redmine_ai_summary).and_return(
        { 'model_parameters_json' => '{"max_completion_tokens":800,"max_tokens":700}' }
      )
      allow(Rails.logger).to receive(:warn)

      expect(described_class.model_parameters).to eq({ max_completion_tokens: 800 })
      expect(Rails.logger).to have_received(:warn).with(/both max_completion_tokens and max_tokens/)
    end
  end
end
