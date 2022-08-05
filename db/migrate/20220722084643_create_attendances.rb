class CreateAttendances < ActiveRecord::Migration[5.1]
  def change
    create_table :attendances do |t|
      t.date :worked_on
      t.datetime :started_at
      t.datetime :finished_at
      t.string :note
      t.string :overwork_status
      t.datetime :overwork_end_time
      t.boolean :overwork_next_day
      t.string :business_process_content
      t.string :superior_confirmation
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
