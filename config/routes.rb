Scioly::Application.routes.draw do

  get "timeslots/update"

  resources :signups, only: [:new, :index, :destroy]

  namespace :admin do
    get 'index'
    get 'events', :as => :events
    get 'scores'
    get 'scorespublish', :as => :scorespublish
    get 'scoreslideshow'
    get "school/edit"
    put "school/update"
  end

  resource :user
  get "user/login", :as => :adminlogin
  post "user/login"
  get "user/logout", :as => :adminlogout
  get 'team', :controller => :home, :action => :team_home, :as=>"team_home"

  resources :teams do
    get 'qualify' # TODO: this is broken

    collection do
      get 'batchnew' => 'teams#batchnew'
      post 'batchnew' => 'teams#batchcreate'
    end
  end

  match 'schools/new' => 'home#newschool', :via => [ :get ], :as => :new_school
  match 'schools/new' => 'home#createschool', :via => [ :post ]

  resources :schedules, :path => "/schedule" do
    get 'scores'
    post 'scores', :action => "savescores"

    collection do
      get 'all_pdfs'
      get 'autocomplete_event' => "schedules#autocomplete_schedule_event"
      get 'batchnew' => "schedules#batchnew"
      post 'batchnew' => "schedules#batchcreate"
      get ':division' => "schedules#index", as: 'division', constraints: { division: /[A-Z]/ }
    end
  end

  resources :timeslots, only: [] do
    get 'register' => 'signups#new'
    get 'confirm' => 'signups#create'
  end

  resources :timeslots

  resources :tournaments do
    collection do
      post 'set_active'
    end

    get 'scores'
    get 'scoreslideshow'
    post 'publish_scores'
    post 'scoreslideshow'
    get 'load_default_events'
  end

  match '/login' => "teams#login"
  match '/login/:division' => "teams#login", :as => :login
  match '/logout' => "teams#logout"

  resources :info

  # Add the Static Pages
  ['about'].each do |static|
    match "/#{static}" => "home##{static}"
  end

  root :to => "home#index"
end
