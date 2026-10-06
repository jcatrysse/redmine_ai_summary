class AiSummariesController < ApplicationController
  before_action :find_issue, only: [:create, :content, :destroy]
  before_action :check_view_permission, only: [:content]
  before_action :check_create_permission, only: [:create]
  before_action :check_destroy_permission, only: [:destroy]

  def content
    summary = IssueSummary.includes(:creator, :updater).find_by(issue_id: @issue.id)
    render partial: 'ai_summaries/summary_content', locals: { issue: @issue, summary: summary }
  end

  def create
    @summary = IssueSummary.find_or_initialize_by(issue_id: @issue.id)
    @summary.status = 'generating'
    @summary.error_message = nil
    @summary.created_by ||= User.current.id

    if @summary.save
      include_subtasks = allow_subtask_generation? && params[:include_subtasks] == '1'
      subtask_depth = include_subtasks ? subtask_max_depth_setting : 0
      GenerateSummaryJob.perform_later(
        @issue.id,
        User.current.id,
        subtask_depth
      )
      handle_success
    else
      handle_error(@summary.errors.full_messages)
    end
  end

  def destroy
    summary = IssueSummary.find_by(id: params[:id], issue_id: @issue.id)
    summary&.destroy
    respond_to do |format|
      format.js
      format.html { redirect_to issue_path(@issue) }
    end
  end

  private

  def find_issue
    @issue = Issue.find(params[:issue_id])
    render_403 unless @issue.visible? && issue_description_accessible?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # redmine_view_issue_description refuses the issue page (not Issue#visible?)
  # to users without view_issue_description; a summary of that issue tells as
  # much as the page, so the same rule applies here when that plugin is loaded.
  def issue_description_accessible?
    return true unless @issue.respond_to?(:description_access_granted?)

    user = User.current
    user.admin? ||
      (@issue.assigned_to.present? && user.is_or_belongs_to?(@issue.assigned_to)) ||
      (@issue.respond_to?(:watcher_access_granted?) && @issue.watcher_access_granted?(user)) ||
      @issue.description_access_granted?(user)
  end

  def check_view_permission
    return if User.current.admin?
    return if User.current.allowed_to?(:view_issue_summary, @issue.project)

    render_403
  end

  def check_create_permission
    return if User.current.admin?

    if params[:include_subtasks] == '1'
      return if User.current.allowed_to?(:generate_issue_summary_with_subtasks, @issue.project)
    else
      return if User.current.allowed_to?(:generate_issue_summary, @issue.project)
    end

    render json: { error: I18n.t('redmine_ai_summary.text.no_permission') }, status: :forbidden
  end

  def check_destroy_permission
    return if User.current.admin?
    return if User.current.allowed_to?(:destroy_issue_summary, @issue.project)

    render_403
  end

  def allow_subtask_generation?
    subtask_max_depth_setting.to_i.positive?
  end

  def subtask_max_depth_setting
    RedmineAiSummary::SettingsResolver.subtask_max_depth(@issue.project)
  end

  def handle_success
    Rails.logger.info "Summary saved/updated for issue ##{@issue.id} by User #{User.current.id}"
    respond_to do |format|
      format.js   # Render create.js.erb for AJAX requests
      format.html { redirect_to issue_path(@issue) }
    end
  end

  def handle_error(errors)
    @errors = Array.wrap(errors)
    Rails.logger.error "Failed to generate summary for issue ##{@issue.id}: #{@errors.join(', ')}"
    respond_to do |format|
      format.js { render json: { error: @errors }, status: :unprocessable_entity }
      format.html do
        flash[:error] = @errors.join(', ')
        redirect_to issue_path(@issue)
      end
    end
  end
end
