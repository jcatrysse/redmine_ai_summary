class AddErrorMessageToIssueSummaries < ActiveRecord::Migration[6.1]
  def change
    add_column :issue_summaries, :error_message, :text
  end
end
