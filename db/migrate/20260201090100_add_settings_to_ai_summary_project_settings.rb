class AddSettingsToAiSummaryProjectSettings < ActiveRecord::Migration[6.1]
  def change
    change_table :ai_summary_project_settings, bulk: true do |t|
      t.boolean :auto_generate
      t.boolean :auto_requires_existing_summary
      t.string :api_endpoint
      t.string :api_key
      t.string :model
      t.text :system_prompt
      t.integer :max_completion_tokens
      t.boolean :debug_logging
      t.boolean :include_journal_changes
    end
  end
end
