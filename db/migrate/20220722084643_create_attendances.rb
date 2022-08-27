class CreateAttendances < ActiveRecord::Migration[5.1]
  def change
    create_table :attendances do |t|
      t.date :worked_on
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :restarted_at
      t.datetime :refinished_at
      t.boolean :next_day
      t.string :note
      t.string :overwork_status
      t.datetime :overwork_end_time
      t.boolean :overwork_next_day
      t.string :business_process_content
      t.string :attendance_change_status
      t.string :superior_confirmation
      t.string :superior_attendance_change_confirmation
      t.boolean :is_check
      t.boolean :change_check
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
