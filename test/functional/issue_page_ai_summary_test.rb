require_relative '../test_helper'

class IssuePageAiSummaryTest < ActionController::TestCase
  tests IssuesController

  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
           :issues, :issue_statuses, :trackers, :projects_trackers, :enumerations,
           :journals, :journal_details, :workflows

  def setup
    @request.session[:user_id] = 1
    EnabledModule.find_or_create_by!(project_id: 1, name: 'ai_summary')
    IssueSummary.create!(issue_id: 1, summary: 'Summary text', status: 'stale', error_message: 'API error')
  end

  def test_summary_actions_carry_svg_icons
    get :show, params: { id: 1 }

    assert_response :success
    if ApplicationHelper.method_defined?(:sprite_icon)
      # Redmine 6+: the icon-* CSS backgrounds are gone, icons are SVG sprites.
      assert_select '#generate-summary-button svg use[href$=?]', '#icon--summary'
      assert_select '#regenerate-summary-button svg use[href$=?]', '#icon--summary'
      assert_select '#issue-summary [data-action=copy_error] svg use[href$=?]', '#icon--warning'
      assert_select '#issue-summary a[data-action=quote] svg use[href$=?]', '#icon--comment'
      assert_select '#issue-summary a[data-action=copy] svg use[href$=?]', '#icon--copy'
      assert_select '#issue-summary a.icon-del svg use[href$=?]', '#icon--del'
    else
      assert_select '#generate-summary-button.icon-summary'
    end
  end
end
