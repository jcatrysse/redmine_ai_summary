module RedmineAiSummary
  class SummaryGenerator
    def self.generate(issue, user, subtask_max_depth: nil)
      begin
        project = issue.respond_to?(:project) ? issue.project : nil
        client = initialize_openai_client(project)

        issue_data = issue_data_for(issue, subtask_max_depth: subtask_max_depth)

        user_prompt = issue_data.to_json

        debug_enabled = RedmineAiSummary::SettingsResolver.debug_logging_enabled?(project)

        response = client.chat(
          parameters: {
            model: RedmineAiSummary::SettingsResolver.model(project),
            messages: [
              { role: "system", content: RedmineAiSummary::SettingsResolver.system_prompt(project) },
              { role: "user", content: user_prompt }
            ],
            **RedmineAiSummary::SettingsResolver.model_parameters(project)
          }
        )

        summary_content = response.dig("choices", 0, "message", "content").to_s
        finish_reason = response.dig("choices", 0, "finish_reason").to_s

        if summary_content.strip.empty?
          Rails.logger.warn("AI Summary returned empty content. finish_reason=#{finish_reason.presence || 'unknown'}")
          return [false, nil, 'AI Summary returned empty content']
        end

        summary = IssueSummary.find_or_initialize_by(issue_id: issue.id)
        summary.summary = summary_content
        summary.updated_at = Time.now
        summary.updated_by = user.id
        summary.error_message = debug_payload(issue_data, response) if debug_enabled

        if summary.save
          return [true, summary, nil]
        else
          Rails.logger.error "Failed to save summary: #{summary.errors.full_messages.join(', ')}"
          return [false, nil, summary.errors.full_messages.join(', ')]
        end
      rescue Faraday::UnauthorizedError => e
        Rails.logger.error "Unauthorized access. Please check your API key and endpoint. Original error: #{e.message}"
        return [false, nil, e.message]
      rescue Faraday::BadRequestError, Faraday::ClientError => e
        response_data = e.response || {}
        Rails.logger.error(
          "AI Summary API error: status=#{response_data[:status]} body=#{response_data[:body]} headers=#{response_data[:headers]}"
        )
        body_details = response_data[:body].to_s
        body_details = body_details.strip
        message = "AI Summary API error: #{response_data[:status]}"
        message = "#{message} - #{body_details}" if body_details.present?
        return [false, nil, message]
      rescue StandardError => e
        Rails.logger.error "An unexpected error occurred during summary generation. Original error: #{e.message}"
        return [false, nil, e.message]
      end
    end

    private

    def self.initialize_openai_client(project)
      options = {
        access_token: RedmineAiSummary::SettingsResolver.api_key(project),
        log_errors: true
      }

      api_endpoint = RedmineAiSummary::SettingsResolver.api_endpoint(project)
      options[:uri_base] = api_endpoint if api_endpoint.present?

      OpenAI::Client.new(options)
    end

    def self.issue_data_for(issue, subtask_max_depth:)
      issue_data = {
        subject: issue.subject,
        description: issue.description,
        text_formatting: Setting.text_formatting,
        changes: issue.changesets.map do |changeset|
          {
            id: changeset.id,
            comments: changeset.comments,
            committed_on: changeset.committed_on
          }
        end,
        notes: issue.journals.map do |journal|
          entry = {
            id: journal.id,
            user: journal.user.login,
            notes: journal.notes,
            created_on: journal.created_on
          }

          if RedmineAiSummary::SettingsResolver.include_journal_changes?(issue.project)
            entry[:details] = journal.details.map do |detail|
              old_value, new_value = resolve_detail_values(detail)
              prop_key = detail.prop_key
              if detail.property == 'cf'
                custom_field = CustomField.find_by(id: detail.prop_key)
                prop_key = custom_field.name if custom_field
              end

              {
                property: detail.property,
                prop_key: prop_key,
                old_value: old_value,
                value: new_value
              }
            end
          end

          entry
        end
      }

      depth = subtask_max_depth || subtask_max_depth_setting(issue)
      if depth.to_i.positive?
        issue_data[:subtasks] = subtasks_for(issue, depth)
      end

      issue_data
    end

    def self.resolve_detail_values(detail)
      old_value = detail.old_value
      new_value = detail.value

      if detail.property == 'cf'
        custom_field = CustomField.find_by(id: detail.prop_key)
        if custom_field
          old_value = custom_field_value_to_string(custom_field, detail.old_value)
          new_value = custom_field_value_to_string(custom_field, detail.value)
        end
        return old_value, new_value
      end

      return old_value, new_value unless detail.property == 'attr'

      case detail.prop_key
      when 'status_id'
        old_value = IssueStatus.find_by(id: detail.old_value)&.name
        new_value = IssueStatus.find_by(id: detail.value)&.name
      when 'priority_id'
        old_value = IssuePriority.find_by(id: detail.old_value)&.name
        new_value = IssuePriority.find_by(id: detail.value)&.name
      when 'tracker_id'
        old_value = Tracker.find_by(id: detail.old_value)&.name
        new_value = Tracker.find_by(id: detail.value)&.name
      when 'assigned_to_id'
        old_value = User.find_by(id: detail.old_value)&.name
        new_value = User.find_by(id: detail.value)&.name
      when 'category_id'
        old_value = IssueCategory.find_by(id: detail.old_value)&.name
        new_value = IssueCategory.find_by(id: detail.value)&.name
      when 'fixed_version_id'
        old_value = Version.find_by(id: detail.old_value)&.name
        new_value = Version.find_by(id: detail.value)&.name
      end

      return old_value, new_value
    end

    def self.subtasks_for(issue, max_depth)
      depth_limit = max_depth.to_i
      return [] if depth_limit <= 0

      results = []
      queue = []

      if issue.respond_to?(:children)
        issue.children.each { |child| queue << [child, 1] }
      elsif issue.respond_to?(:descendants)
        issue.descendants.each { |child| queue << [child, 1] }
      end

      while (entry = queue.shift)
        subtask, depth = entry
        results << {
          id: subtask.id,
          subject: subtask.subject,
          description: subtask.description,
          status: subtask.status&.name,
          assigned_to: subtask.assigned_to&.name,
          depth: depth
        }

        next if depth >= depth_limit
        next unless subtask.respond_to?(:children)

        subtask.children.each { |child| queue << [child, depth + 1] }
      end

      results
    end

    def self.subtask_max_depth_setting(issue)
      RedmineAiSummary::SettingsResolver.subtask_max_depth(issue.project)
    end

    def self.custom_field_value_to_string(custom_field, value)
      return value if custom_field.nil?

      if custom_field.respond_to?(:value_to_string)
        return custom_field.value_to_string(value)
      end

      format = custom_field.format if custom_field.respond_to?(:format)
      return value unless format&.respond_to?(:value_to_string)

      arity = format.method(:value_to_string).arity
      if arity == 1
        format.value_to_string(value)
      else
        format.value_to_string(value, custom_field)
      end
    end

    def self.debug_payload(issue_data, response)
      {
        request: issue_data,
        response: response
      }.to_json
    end
  end
end
