# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get 'import/index', :to => "user_imports#index"
get 'import/download', :to => "user_imports#download"
post 'import/create', :to => "user_imports#create"
post 'import/createUser', :to => "user_imports#create_user"
