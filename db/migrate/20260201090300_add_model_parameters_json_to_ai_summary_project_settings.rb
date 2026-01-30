class AddModelParametersJsonToAiSummaryProjectSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :ai_summary_project_settings, :model_parameters_json, :text
  end
end
