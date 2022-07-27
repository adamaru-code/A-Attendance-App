class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include SessionsHelper # モジュールの読み込みを設定
  
  $days_of_the_week = %w{日 月 火 水 木 金 土} # Rubyのリテラル表記
  
  # beforフィルター
  
  # paramsハッシュからユーザーを取得します。
  def set_user
    @user = User.find(params[:id])
  end

  # ログイン済みのユーザーか確認します。
  def logged_in_user
    unless logged_in?
      store_location
      flash[:danger] = "ログインしてください。"
      redirect_to login_url
    end
  end
  
 # アクセスしたユーザーが現在ログインしているユーザーか確認します。
  def correct_user
    # @user = User.find(params[:id])
    # redirect_to(root_url) unless @user == current_user
    redirect_to(root_url) unless current_user?(@user) # ヘルパーのdef current_user?(user)を用いて書き換え
  end
  
  # システム管理権限所有かどうか判定します。
  def admin_user
    redirect_to root_url unless current_user.admin?
  end
  
  # ページ出力前に1ヶ月分のデータの存在を確認・セットします。
  # before_actionとして実行(今のところ対象はusersコントローラーのshowアクション)
  # その為、@first_dayと@last_dayはshowアクションからこちらへ引っ越す
  def set_one_month 
    # @first_day = Date.current.beginning_of_month
    @first_day = params[:date].nil? ? Date.current.beginning_of_month : params[:date].to_date
    # パターン2 
    # @first_day = if params[:date].nil?
            #   Date.current.beginning_of_month
            # else
            #   params[:date].to_date
            # end
    # パターン3
    # if params[:date].nil?
    #   @first_day = Date.current.beginning_of_month
    # else
    #   @first_day = params[:date].to_date
    # end
    @last_day = @first_day.end_of_month
    # 対象の月の日数を1ヶ月分のオブジェクトが代入された配列[*..]として代入します。
    # showアクションでは使わない為ローカル変数に代入しています。
    one_month = [*@first_day..@last_day]
    
    # ユーザーに紐付く一ヶ月分のレコードを検索し取得します。showアクションでも使用することになる為インスタンス変数に代入
    # .attendancesという複数形の記述はActivbeRecord特有の記法で、対象のモデル（今回はUserモデル）に紐付くモデルを指定します。
    # whereメソッド、引数にはworked_onをキーとして定義済みのインスタンス変数を範囲として指定
    # orderメソッドで昇順に並び替え
    @attendances = @user.attendances.where(worked_on: @first_day..@last_day).order(:worked_on)

    # それぞれの件数（日数）が一致するか評価します。
    unless one_month.count == @attendances.count # このcountメソッドは、対象のオブジェクトが配列の場合要素数を返します。
      ActiveRecord::Base.transaction do # トランザクションを開始します(ブロック内で例外処理が発生した場合にロールバックが発動する仕組みとなっています)
        # ブロック内で繰り返し処理により、1ヶ月分の勤怠データを生成します。
        one_month.each { |day| @user.attendances.create!(worked_on: day) }
      end
      @attendances = @user.attendances.where(worked_on: @first_day..@last_day).order(:worked_on)
    end

  rescue ActiveRecord::RecordInvalid # トランザクションによるエラーの分岐です。
    flash[:danger] = "ページ情報の取得に失敗しました、再アクセスしてください。"
    redirect_to root_url # トップページへとリダイレクト
  end  
end
