require_relative '../test_helper'

class AiSummarySettingsControllerTest < ActionController::TestCase
  def setup
    @request.session[:user_id] = 1
  end

  def test_models_returns_success_for_admin
    RedmineAiSummary::SettingsTester.stubs(:list_models).returns(
      { success: true, message: 'ok', models: ['model-1'], data: {} }
    )

    get :models

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body['success']
    assert_equal ['model-1'], body['models']
  end

  def test_test_returns_error_details
    RedmineAiSummary::SettingsTester.stubs(:test_connection).returns(
      { success: false, message: 'HTTP 400: bad request', models: [], data: {} }
    )

    post :test

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_equal 'HTTP 400: bad request', body['message']
  end

  def test_requires_admin
    @request.session[:user_id] = 2

    get :models

    assert_response :forbidden
  end
end
