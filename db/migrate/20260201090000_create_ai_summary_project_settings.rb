class CreateAiSummaryProjectSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :ai_summary_project_settings do |t|
      t.integer :project_id, null: false
      t.integer :subtask_summary_max_depth

      t.timestamps
    end

    add_index :ai_summary_project_settings, :project_id, unique: true
  end
end
