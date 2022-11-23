class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy, :edit_basic_info, :update_basic_info, :list_of_employees]
  before_action :logged_in_user, only: [:index, :edit, :update, :destroy, :edit_basic_info, :update_basic_info, :list_of_employees, :edit_system_info]
  before_action :correct_user, only: [:edit, :update]
  before_action :admin_user, only: [:index, :destroy, :edit_basic_info, :update_basic_info, :list_of_employees, :edit_system_info]
  before_action :not_allow_admin_user, only: :show
  before_action :set_one_month, only: :show
  
  def index
    @users = User.where.not(id: 1)
  end
  
  def show
    # @first_day = Date.current.beginning_of_month # Date.currentで当日を取得
    # @last_day = @first_day.end_of_month
    @worked_sum = @attendances.where.not(started_at: nil).count
    @superior = User.where(superior: true).where.not(id: @user.id)
    @attendance = @user.attendances.find_by(worked_on: @first_day)
    if current_user.superior?      
      @overwork_sum = Attendance.includes(:user).where(superior_confirmation: current_user.id, overwork_status: "申請中").count
      # @attendance_change_sum = Attendance.includes(:user).where(superior_attendance_change_confirmation: current_user.name, attendance_change_status: "申請中").count
      @attendance_change_sum = Attendance.where(superior_attendance_change_confirmation: current_user.name, attendance_change_status: "申請中").count
      @one_month_approval_sum = Attendance.includes(:user).where(superior_month_notice_confirmation: current_user.id, one_month_approval_status: "申請中").count
    end
    
    # csv出力
    respond_to do |format|
      format.html 
      format.csv do |csv|
        send_attndances_csv(@attendances)
      end
    end   
  end
  
  def new
    @user = User.new
  end
  
  def create
    @user = User.new(user_params)
    if @user.save
      log_in @user # 保存成功後、ログインします。
      flash[:success] = '新規作成に成功しました。'
      redirect_to @user
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @user.update_attributes(user_params)
      flash[:success] = "ユーザー情報を更新しました。"
      redirect_to @user
    else
      render :edit
    end
  end
  
  def destroy
    @user.destroy
    flash[:success] = "#{@user.name}のデータを削除しました。"
    redirect_to users_url
  end
  
  def edit_basic_info
  end

  def update_basic_info
    if @user.update_attributes(basic_info_params)
      flash[:success] = "#{@user.name}の基本情報を更新しました。"
    else
      flash[:danger] = "#{@user.name}の更新は失敗しました。<br>" + @user.errors.full_messages.join("<br>")
    end
    redirect_to users_url
  end
  
  def import
    if params[:file].blank?
      flash[:danger]= "csvファイルを選択してください"
    else
      User.import(params[:file])
      flash[:success] = "csvファイルをインポートしました。"
    end
    redirect_to users_url
  end
  
  # def import
  #   if params[:file].blank?
  #     flash[:danger] = "CSVファイルが選択されていません。"
  #   redirect_to users_url
  #   else
  #     if User.import(params[:file])
  #       flash[:success] = "CSVファイルのインポートに成功しました。"
  #     else
  #       flash[:danger] = "CSVファイルのインポートに失敗しました。"
  #     end
  #     redirect_to users_url
  #   end
  # end
  
  def list_of_employees
    @users = User.all.includes(:attendances)
  end
  
  def edit_system_info
  end
  
  private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end
    
    def basic_info_params
      params.require(:user).permit(:name,
                                   :email,
                                   :affiliation,
                                   :employee_number,
                                   :uid,
                                   :password,
                                   :basic_work_time,
                                   :designated_work_start_time,
                                   :designated_work_end_time)
    end
    
    def send_attndances_csv(attendances)
      #文字化け防止
      bom = "\uFEFF"
      # CSV.generateとは、対象データを自動的にCSV形式に変換してくれるCSVライブラリの一種
      csv_data = CSV.generate(bom, encoding: Encoding::SJIS, row_sep: "\r\n", force_quotes: true) do |csv|
        # %w()は、空白で区切って配列を返します
        column_names = %w(日付 曜日 出勤時間 退勤時間)
        # csv << column_namesは表の列に入る名前を定義します。
        csv << column_names
        # column_valuesに代入するカラム値を定義します。
        @attendances = @user.attendances.where(worked_on: @first_day..@last_day).order(:worked_on)
        @attendances.each do |day|
          column_values = [
            l(day.worked_on, format: :short),
            $days_of_the_week[day.worked_on.wday],
            if day.started_at.present? && (day.attendance_change_status == "承認").present?
              l(day.started_at.floor_to(60*15), format: :time)
            else
              ""
            end,
            if day.finished_at.present? && (day.attendance_change_status == "承認").present?
              l(day.finished_at.floor_to(60*15), format: :time)
            else
              ""
            end
          ]
        # csv << column_valueshは表の行に入る値を定義します。
          csv << column_values
        end
      end
      # csv出力のファイル名を定義します。
      send_data(csv_data, filename: "勤怠一覧.csv")
    end
end