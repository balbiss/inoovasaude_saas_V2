class AdaptAppointmentsForClinic < ActiveRecord::Migration[8.1]
  def change
    add_reference :appointments, :professional, foreign_key: true
    add_reference :appointments, :service, foreign_key: true
    add_column :appointments, :consultation_type, :string
    add_column :appointments, :notes, :text
    add_column :appointments, :confirmation_sent_at, :datetime
    add_column :appointments, :reminder_sent_at, :datetime

    remove_reference :appointments, :property, foreign_key: true if column_exists?(:appointments, :property_id)
    remove_column :appointments, :broker_name, :string if column_exists?(:appointments, :broker_name)
  end
end
