require_relative '../test_helper'

class SettingsTesterTest < ActiveSupport::TestCase
  def test_format_error_includes_body_details
    response = Struct.new(:status, :body).new(400, { 'error' => 'invalid key' })

    message = RedmineAiSummary::SettingsTester.send(:format_error, response)

    assert_equal 'HTTP 400: invalid key', message
  end
end
