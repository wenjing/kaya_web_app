KayaWebApp::Application.routes.draw do

  resources :users, :only => [:new, :edit, :show, :create, :update] do
    resources :mposts, :only => [:create]
    resources :invitations, :only => [:create, :new]
    member do
      get :meets, :friends, :cirkles, :news, :map, :pending_meets
    end
  end
  resources :meets, :only => [:show, :edit, :update, :destroy] do
    resources :invitations, :only => [:create, :new]
    resources :chatters,    :only => [:create]
    member do
      get    :map
      post   :confirm
      delete :decline
    end
  end
  resources :chatters, :only => [:create, :destroy] do
    resources :comments,    :only => [:create], :controller => :chatters
  end
  
  resources :sessions,      :only => [:new, :create, :destroy]
  resources :mposts,	    :only => [:create, :show]
  resources :invitations,   :only => [:create]
  get  :new_reset,    :controller => :sessions, :as => :new_reset_session
  post :create_reset, :controller => :sessions, :as => :reset_sessions

  root :to => "pages#home"

  match '/contact', :to => 'pages#contact'
  match '/about',   :to => 'pages#about'
  match '/help',    :to => 'pages#help'
  match '/signup',  :to => 'users#new'
  match '/signin',  :to => 'sessions#new'
  match '/password_reset',  :to => 'sessions#new_reset'
  match '/signout', :to => 'sessions#destroy'

  if Rails.env.development?
    post  '/debug/run',    :to => "debug#run"
    get   '/debug/mposts', :to => "debug#mposts"
  end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get :short
  #       post :toggle
  #     end
  #
  #     collection do
  #       get :sold
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get :recent, :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
