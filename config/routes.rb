Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # LLM API endpoints for MCP integration
  scope :llm do
    get  :funds,        to: 'llm#funds'
    get  :positions,    to: 'llm#positions'
    get  :orders,       to: 'llm#orders'
    get  :spot,         to: 'llm#spot'
    get  :quote,        to: 'llm#quote'
    get  :option_chain, to: 'llm#option_chain'
    post :place_bracket_order, to: 'llm#place_bracket_order'
    post :modify_order,        to: 'llm#modify_order'
    post :cancel_order,        to: 'llm#cancel_order'

    # AI Analysis endpoints
    post :analyze_market, to: 'llm#analyze_market'
    post :trading_recommendations, to: 'llm#trading_recommendations'
    post :ai_decision,           to: 'llm#ai_decision'
    get  :test_ai_connection,    to: 'llm#test_ai_connection'
    post :custom_analysis,       to: 'llm#custom_analysis'
  end

  # Autopilot management endpoints
  scope :autopilot do
    get :status, to: 'autopilot#status'
    post :start, to: 'autopilot#start'
    post :stop, to: 'autopilot#stop'
    post :signal, to: 'autopilot#send_signal'
    get :agent_health, to: 'autopilot#agent_health'
  end

  # Trading engine management endpoints
  scope :trading do
    get :status, to: 'trading#status'
    post :start, to: 'trading#start'
    post :stop, to: 'trading#stop'
    get :positions, to: 'trading#positions'
    get 'positions/:id', to: 'trading#show_position'
    post 'positions/:id/close', to: 'trading#close_position'
    post :close_all, to: 'trading#close_all_positions'
    get :signals, to: 'trading#signals'
    post :process_signals, to: 'trading#process_signals'
    get :stats, to: 'trading#stats'
    get :health, to: 'trading#health'
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
