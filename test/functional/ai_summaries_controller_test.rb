require_relative '../test_helper'

class AiSummariesControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
           :issues, :issue_statuses, :trackers, :projects_trackers, :enumerations

  def setup
    EnabledModule.find_or_create_by!(project_id: 1, name: 'ai_summary')
    @issue = Issue.find(1)
    @summary = IssueSummary.create!(issue_id: @issue.id, summary: 'Secret summary text', status: 'up_to_date')
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end

  def test_content_is_shown_to_a_user_who_sees_the_issue
    # With redmine_view_issue_description installed, seeing the issue page takes this permission too.
    Role.anonymous.add_permission!(:view_issue_description) if Redmine::AccessControl.permission(:view_issue_description)

    get :content, params: { issue_id: @issue.id }

    assert_response :success
    assert_includes response.body, 'Secret summary text'
  end

  # view_issue_summary is a public permission: anyone who may see the project
  # has it, so the issue's own visibility must be checked as well.
  def test_content_of_a_private_issue_is_refused_to_a_user_who_cannot_see_it
    @issue.update_column(:is_private, true)
    refute @issue.reload.visible?(User.anonymous)

    get :content, params: { issue_id: @issue.id }

    assert_response :forbidden
    refute_includes response.body, 'Secret summary text'
  end

  def test_destroy_on_an_issue_the_user_cannot_see_is_refused
    @issue.update_column(:is_private, true)
    Role.anonymous.add_permission!(:destroy_issue_summary)

    delete :destroy, params: { issue_id: @issue.id, id: @summary.id }

    assert_response :forbidden
    assert IssueSummary.exists?(@summary.id)
  end

  def test_create_on_an_issue_the_user_cannot_see_is_refused
    @issue.update_column(:is_private, true)
    Role.anonymous.add_permission!(:generate_issue_summary)

    post :create, params: { issue_id: @issue.id }, xhr: true

    assert_response :forbidden
    assert_equal 'up_to_date', @summary.reload.status
  end

  def test_content_of_a_missing_issue_is_not_found
    get :content, params: { issue_id: 999_999 }

    assert_response :not_found
  end

  # redmine_view_issue_description (GEOxyz) refuses the issue page to users
  # without view_issue_description; the summary of that issue must follow.
  def test_content_follows_redmine_view_issue_description_when_installed
    @request.session[:user_id] = 2
    Issue.any_instance.stubs(:description_access_granted?).returns(false)
    Issue.any_instance.stubs(:watcher_access_granted?).returns(false)

    get :content, params: { issue_id: @issue.id }

    assert_response :forbidden
    refute_includes response.body, 'Secret summary text'
  end

  def test_content_shown_when_redmine_view_issue_description_grants_access
    @request.session[:user_id] = 2
    Issue.any_instance.stubs(:description_access_granted?).returns(true)
    Issue.any_instance.stubs(:watcher_access_granted?).returns(false)

    get :content, params: { issue_id: @issue.id }

    assert_response :success
    assert_includes response.body, 'Secret summary text'
  end
end
