class AttendancesController < ApplicationController
  before_action :set_user, only: [:edit_one_month, :update_one_month, :edit_overwork_notice, :edit_attendance_change, :update_attendance_change, :update_month_request, :edit_one_month_approval]
  before_action :logged_in_user, only: [:update, :edit_one_month, :log_attendance_change]
  before_action :set_attendance, only: [:update, :edit_overwork_request, :update_overwork_request, :edit_overwork_notice, :log_attendance_change]
  before_action :edit_one_month_correct_user, only: [:update, :edit_one_month, :update_one_month, :log_attendance_change]
  before_action :set_one_month, only: [:edit_one_month, :edit_overwork_notice, :edit_attendance_change, :log_attendance_change]
  before_action :not_allow_admin_user, only: [:edit_one_month]
  
  UPDATE_ERROR_MSG = "勤怠登録に失敗しました。やり直してください。"
  
  def update
    @user = User.find(params[:user_id])
    # 出勤時間が未登録であることを判定します。
    if @attendance.started_at.nil?
      if @attendance.update_attributes(started_at: Time.current.change(sec: 0))
        flash[:info] = "おはようございます！"
      else
        flash[:danger] = "勤怠登録に失敗しました。やり直してください。"
      end
    elsif @attendance.finished_at.nil?
      if @attendance.update_attributes(finished_at: Time.current.change(sec: 0))
        flash[:info] = "お疲れ様でした。"
      else
        flash[:danger] = UPDATE_ERROR_MSG
      end
    end
    redirect_to @user
  end
  
  #勤怠変更
  def edit_one_month
    @superior = User.where(superior:true).where.not(id:current_user.id)
  end
  
  def update_one_month
    @superior = User.where(superior:true).where.not(id:current_user.id)
    a_count = 0
    ActiveRecord::Base.transaction do # トランザクションを開始します。
      attendances_params.each do |id, item|
        if item[:superior_attendance_change_confirmation].present?
          if item[:refinished_at].blank? && item[:restarted_at].present?
            flash[:danger] = "退勤時間が必要です。"
            redirect_to attendances_edit_one_month_user_url(date: params[:date]) and return
          elsif item[:restarted_at].blank? && item[:refinished_at].present?
            flash[:danger] = "出勤時間が必要です。"
            redirect_to attendances_edit_one_month_user_url(date: params[:date]) and return
          elsif item[:restarted_at].present? && item[:refinished_at].present? && item[:restarted_at].to_s > item[:refinished_at].to_s
            flash[:danger] = "時刻に誤りがあります。"
            redirect_to attendances_edit_one_month_user_url(date: params[:date]) and return
          end
          attendance = Attendance.find(id)
          attendance.attendance_change_status = "申請中"
          a_count += 1
          attendance.update_attributes!(item) # !をつけている場合はfalseでは無く例外処理を返します。
        end
      end
    end
    if a_count > 0
      flash[:success] = "勤怠編集を#{a_count}件、申請しました。"
      redirect_to user_url(date: params[:date]) and return
    else
      flash[:info] = "勤怠編集はありません。"
      redirect_to user_url(date: params[:date]) and return
    end
  rescue ActiveRecord::RecordInvalid # トランザクションによるエラーの分岐です。
    flash[:danger] = "無効な入力データがあった為、更新をキャンセルしました。"
    redirect_to attendances_edit_one_month_user_url(date: params[:date])
  end

  #勤怠変更の承認
  def edit_attendance_change
    @change_attendances = Attendance.where(superior_attendance_change_confirmation: @user.name, attendance_change_status: "申請中").order(:worked_on).group_by(&:user_id)
  end

  def update_attendance_change
    attendance_change_params.each do |id, item|
      attendance = Attendance.find(id)
      if item[:change_check]
        if item[:attendance_change_status] == "承認"
          if attendance.before_started_at.blank? && attendance.before_finished_at.blank?
            attendance.before_started_at = attendance.started_at
            attendance.before_finished_at = attendance.finished_at
          end
          attendance.started_at = attendance.restarted_at
          attendance.finished_at = attendance.refinished_at
        elsif item[:attendance_change_status] == "否認"
          attendance.started_at = attendance.before_started_at
          attendance.finished_at = attendance.before_finished_at
        elsif item[:attendance_change_status] == "なし"
          attendance.started_at = nil
          attendance.finished_at = nil
          attendance.note = nil
          item[:attendance_change_status] = nil
        end
        item[:change_check] = nil
        attendance.update(item)
        flash[:success] = "勤怠変更申請の承認結果を送信しました。"
      end
    end
    redirect_to user_url(@user)
  end

  #残業申請
  def edit_overwork_request
    @user = User.find(params[:user_id])
    @superior = User.where(superior:true).where.not(id:current_user.id)
  end

  def update_overwork_request
    @user = User.find(params[:user_id])
    @superior = User.where(superior:true).where.not(id:current_user.id)
    if overwork_request_params[:superior_confirmation].present? && overwork_request_params[:overwork_end_time].present? 
      @attendance.update(overwork_request_params)
      flash[:success] = "#{@user.name}の残業を申請しました。"
    elsif overwork_request_params[:superior_confirmation].blank? && overwork_request_params[:overwork_end_time].present? 
      flash[:danger] = "所属長を選択してください。"
    elsif overwork_request_params[:superior_confirmation].present? && overwork_request_params[:overwork_end_time].blank? 
      flash[:danger] = "終了予定時間を入力してください。"
    elsif overwork_request_params[:superior_confirmation].blank? && overwork_request_params[:overwork_end_time].blank? 
      flash[:danger] = "終了予定時間を入力、所属長を選択してください。"
    end
    redirect_to user_url(@user)
  end

  #残業申請の承認
  def edit_overwork_notice
    @overwork_attendances = Attendance.where(superior_confirmation: @user.id, overwork_status: "申請中").order(:user_id, :worked_on).group_by(&:user_id)
  end

  def update_overwork_notice
    @user = User.find(params[:user_id])
    overwork_notice_params.each do |id, item|
      attendance = Attendance.find(id)
      if item[:is_check]
        if item[:overwork_status] == "なし"
          attendance.overwork_end_time = nil
          attendance.superior_confirmation = nil
          attendance.business_process_content = nil
          item[:overwork_status] = nil
          item[:is_check] = nil
        end
        attendance.update(item)
        flash[:success] = "残業申請の承認結果を送信しました。"
      else
        flash[:danger] = "承認確認のチェックを入れてください。"
      end
    end
    redirect_to user_url(@user)
  end

  #1ヶ月分の勤怠申請
  def update_month_request
    @superior = User.where(superior:true).where.not(id:current_user.id)
    @attendance = @user.attendances.find_by(worked_on: params[:attendance][:day])
    if month_request_params[:superior_month_notice_confirmation].present?
      @attendance.update(month_request_params)
      flash[:success] = "#{@user.name}の1か月分の申請をしました。"
    else
      flash[:danger]= "所属長を選択してください。"
    end
    redirect_to user_url(@user)
  end

   #1ヶ月分の勤怠所属長承認
  def edit_one_month_approval
    @month_attendances = Attendance.where(superior_month_notice_confirmation: @user.id, one_month_approval_status: "申請中").order(:user_id, :worked_on).group_by(&:user_id)
  end

  def update_one_month_approval
    @user = User.find(params[:user_id])
    month_approval_params.each do |id, item|
      attendance = Attendance.find(id)
      if item[:approval_check]
        if item[:one_month_approval_status] == "なし"
          item[:one_month_approval_status] = nil
          item[:approval_check] = nil
        end 
        attendance.update(item)
        flash[:success] = "勤怠申請の承認結果を送信しました。"
      else
        flash[:danger] = "承認確認のチェックを入れてください。" 
      end
    end
    redirect_to user_url(@user)
  end
  
    #勤怠ログ
  def log_attendance_change
    @user = User.find(params[:user_id])
    if params["select_year(1i)"].present? && params["select_month(2i)"].present?
      @first_day = (params["select_year(1i)"] + "-" + params["select_month(2i)"] + "-01").to_date
      @attendances = @user.attendances.where(worked_on: @first_day..@first_day.end_of_month, attendance_change_status: "承認").order(:worked_on)
    end
  end
  
  private
    # 1ヶ月分の勤怠情報を扱います。
    def attendances_params
      params.require(:user).permit(attendances: [:started_at, :finished_at,
                                                 :restarted_at, :refinished_at,
                                                 :next_day, :note,
                                                 :superior_attendance_change_confirmation,
                                                 :attendance_change_status])[:attendances]
    end
    
    def attendance_change_params
      params.require(:user).permit(attendances: [:change_check, :attendance_change_status])[:attendances]
    end
    
    def overwork_request_params
      params.require(:attendance).permit(:overwork_end_time, :overwork_next_day, :business_process_content, :superior_confirmation, :overwork_status)
    end
    
    def overwork_notice_params
      params.require(:user).permit(attendances: [:is_check, :overwork_status])[:attendances]
    end
    
    def month_request_params
      params.require(:attendance).permit(:superior_month_notice_confirmation, :one_month_approval_status)
    end
    
    def month_approval_params
      params.require(:user).permit(attendances: [:approval_check, 
                                                 :one_month_approval_status])[:attendances]
    end
    
    # beforeフィルター

    # 現在ログインしているユーザーを許可します。
    def edit_one_month_correct_user
      @user = User.find(params[:user_id]) if @user.blank?
      unless current_user?(@user)
        flash[:danger] = "編集権限がありません。"
        redirect_to(root_url)
      end
    end
    
    def set_attendance
      @attendance = Attendance.find(params[:id])
    end

    def set_superior
      @superior = User.where(superior:true).where.not(id:current_user.id)
    end
end