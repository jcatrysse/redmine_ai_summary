require 'cgi'

module RedmineAiSummary
  class SettingsTester
    DEFAULT_OPENAI_ENDPOINT = 'https://api.openai.com/v1'
    DEFAULT_ANTHROPIC_ENDPOINT = 'https://api.anthropic.com/v1'
    DEFAULT_GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta'
    ANTHROPIC_VERSION = '2023-06-01'

    def self.test_connection
      config = api_config
      return failure('API key is missing') if config[:api_key].blank?

      case config[:provider]
      when :anthropic
        test_anthropic(config)
      when :gemini
        test_gemini(config)
      else
        test_openai(config)
      end
    end

    def self.list_models
      config = api_config
      return failure('API key is missing') if config[:api_key].blank?

      case config[:provider]
      when :anthropic
        list_anthropic_models(config)
      when :gemini
        list_gemini_models(config)
      else
        list_openai_models(config)
      end
    end

    def self.test_openai(config)
      url = "#{config[:base_url]}/chat/completions"
      parameters = model_parameters_for_test
      payload = {
        model: config[:model].presence || 'gpt-3.5-turbo',
        messages: [
          { role: 'user', content: 'ping' }
        ]
      }
      payload.merge!(parameters) if parameters.any?
      response = request_json(url, headers: bearer_headers(config), payload: payload)
      return response if response[:success]

      failure("Test failed: #{response[:message]}")
    end

    def self.list_openai_models(config)
      url = "#{config[:base_url]}/models"
      response = request_json(url, headers: bearer_headers(config))
      return response unless response[:success]

      models = Array(response[:data]['data']).map { |item| item['id'] }.compact
      success('Models fetched.', models: models)
    end

    def self.test_anthropic(config)
      url = "#{config[:base_url]}/messages"
      payload = {
        model: config[:model].presence || 'claude-3-haiku-20240307',
        max_tokens: 1,
        messages: [
          { role: 'user', content: 'ping' }
        ]
      }
      response = request_json(url, headers: anthropic_headers(config), payload: payload)
      return response if response[:success]

      failure("Test failed: #{response[:message]}")
    end

    def self.list_anthropic_models(config)
      url = "#{config[:base_url]}/models"
      response = request_json(url, headers: anthropic_headers(config))
      return response unless response[:success]

      models = Array(response[:data]['data']).map { |item| item['id'] }.compact
      success('Models fetched.', models: models)
    end

    def self.test_gemini(config)
      url = "#{config[:base_url]}/models/#{config[:model].presence || 'gemini-1.5-pro'}:generateContent"
      response = request_json(url_with_key(url, config[:api_key]), payload: {
        contents: [
          { parts: [{ text: 'ping' }] }
        ]
      })
      return response if response[:success]

      failure("Test failed: #{response[:message]}")
    end

    def self.list_gemini_models(config)
      url = "#{config[:base_url]}/models"
      response = request_json(url_with_key(url, config[:api_key]))
      return response unless response[:success]

      models = Array(response[:data]['models']).map { |item| item['name'] }.compact
      success('Models fetched.', models: models)
    end

    def self.request_json(url, headers: {}, payload: nil)
      connection = Faraday.new do |builder|
        builder.request :json
        builder.response :json, content_type: /\bjson$/
        builder.adapter Faraday.default_adapter
      end

      response = if payload
                   connection.post(url, payload, headers)
                 else
                   connection.get(url, nil, headers)
                 end

      if response.success?
        success('OK', data: response.body || {})
      else
        failure(format_error(response))
      end
    rescue Faraday::Error => e
      failure(e.message)
    end

    def self.success(message, data: {}, models: [])
      { success: true, message: message, data: data, models: models }
    end

    def self.failure(message)
      { success: false, message: message, data: {}, models: [] }
    end

    def self.format_error(response)
      body = response.body
      message = body.is_a?(Hash) ? body['error'] || body['message'] : body.to_s
      details = message.to_s.strip
      details = response.status.to_s if details.empty?
      "HTTP #{response.status}: #{details}"
    end

    def self.api_config
      settings = Setting.plugin_redmine_ai_summary
      endpoint = settings['api_endpoint'].presence
      provider = detect_provider(endpoint)
      base = normalize_base_url(endpoint, provider)

      {
        api_key: settings['api_key'].to_s,
        model: settings['model'].to_s,
        base_url: base,
        provider: provider
      }
    end

    def self.model_parameters_for_test
      parameters = RedmineAiSummary::SettingsResolver.model_parameters
      return { max_completion_tokens: 128 } if parameters.empty?

      updated = parameters.dup
      if updated.key?(:max_completion_tokens) && updated.key?(:max_tokens)
        updated.delete(:max_tokens)
      end
      if updated.key?(:max_completion_tokens)
        updated[:max_completion_tokens] = 128
      elsif updated.key?(:max_tokens)
        updated[:max_tokens] = 128
      else
        updated[:max_completion_tokens] = 128
      end
      updated
    end

    def self.detect_provider(endpoint)
      return :openai if endpoint.blank?

      normalized = endpoint.to_s
      return :openai if normalized.include?('/openai/')
      return :anthropic if normalized.include?('anthropic.com')
      return :gemini if normalized.include?('generativelanguage.googleapis.com')

      :openai
    end

    def self.normalize_base_url(endpoint, provider)
      if endpoint.blank?
        return DEFAULT_ANTHROPIC_ENDPOINT if provider == :anthropic
        return DEFAULT_GEMINI_ENDPOINT if provider == :gemini

        return DEFAULT_OPENAI_ENDPOINT
      end

      base = endpoint.to_s.sub(%r{/\z}, '')
      if provider == :gemini
        return base if base.include?('/v1beta')

        return "#{base}/v1beta"
      end

      return base if base.end_with?('/v1') || base.include?('/openai/v1')

      "#{base}/v1"
    end

    def self.bearer_headers(config)
      {
        'Authorization' => "Bearer #{config[:api_key]}",
        'Content-Type' => 'application/json'
      }
    end

    def self.anthropic_headers(config)
      {
        'x-api-key' => config[:api_key],
        'anthropic-version' => ANTHROPIC_VERSION,
        'Content-Type' => 'application/json'
      }
    end

    def self.url_with_key(url, api_key)
      separator = url.include?('?') ? '&' : '?'
      "#{url}#{separator}key=#{CGI.escape(api_key)}"
    end
  end
end
