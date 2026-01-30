class AiSummaryProjectSetting < ActiveRecord::Base
  self.table_name = 'ai_summary_project_settings'

  belongs_to :project

  validates :subtask_summary_max_depth,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :max_completion_tokens,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  validate :model_parameters_json_format

  private

  def model_parameters_json_format
    return if model_parameters_json.blank?

    parsed = JSON.parse(model_parameters_json)
    return if parsed.is_a?(Hash)

    errors.add(:model_parameters_json, :invalid)
  rescue JSON::ParserError
    errors.add(:model_parameters_json, :invalid)
  end
end
