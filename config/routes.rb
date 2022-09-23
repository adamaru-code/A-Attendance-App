Rails.application.routes.draw do
  root 'static_pages#top'
  get '/signup', to: 'users#new'
  
  # ログイン機能
  get    '/login', to: 'sessions#new'
  post   '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'
  
  resources :users do
    collection {post :import}
    member do
      get 'edit_basic_info'
      patch 'update_basic_info'
      # １ヶ月分の変更申請 
      get 'attendances/edit_one_month'
      patch 'attendances/update_one_month'
      
    end
    resources :attendances, only: [:update] do
      member do
        # 残業申請モーダル
        get 'edit_overwork_request'
        patch 'update_overwork_request'
        # 残業申請のお知らせ承認モーダル
        get 'edit_overwork_notice'
        patch 'update_overwork_notice'
        # 勤怠承認
        get 'edit_attendance_change'
        patch 'update_attendance_change'
        # 勤怠ログ
        get 'log_attendance_change'
      end
    end
  end  
end