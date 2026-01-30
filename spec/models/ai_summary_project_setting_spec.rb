require_relative '../rails_helper'

RSpec.describe AiSummaryProjectSetting, type: :model do
  fixtures :projects

  let(:project) { projects(:projects_001) }

  it 'is valid with blank model parameters JSON' do
    setting = described_class.new(project: project, model_parameters_json: '')
    expect(setting).to be_valid
  end

  it 'is invalid with malformed JSON' do
    setting = described_class.new(project: project, model_parameters_json: '{bad json')
    expect(setting).not_to be_valid
    expect(setting.errors[:model_parameters_json]).to be_present
  end

  it 'is invalid when JSON is not an object' do
    setting = described_class.new(project: project, model_parameters_json: '[]')
    expect(setting).not_to be_valid
    expect(setting.errors[:model_parameters_json]).to be_present
  end
end
