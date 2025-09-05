Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

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
  end
end
