# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :issues do
  resources :ai_summaries, only: [:create, :destroy] do
    get :content, on: :collection
  end
end

resources :projects do
  resource :ai_summary_settings, only: [:update], controller: 'ai_summary_project_settings'
end

resource :ai_summary_settings, only: [], controller: 'ai_summary_settings' do
  get :models
  post :test
end
