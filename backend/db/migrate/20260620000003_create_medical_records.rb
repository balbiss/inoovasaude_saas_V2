class CreateMedicalRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :medical_records do |t|
      t.references :account, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: { to_table: :contacts }
      t.references :professional, foreign_key: true
      t.references :appointment, foreign_key: true
      t.bigint :recorded_by_id
      t.text :chief_complaint
      t.text :diagnosis
      t.text :prescription
      t.text :notes
      t.timestamps
    end

    add_foreign_key :medical_records, :users, column: :recorded_by_id
    add_index :medical_records, :account_id
    add_index :medical_records, :patient_id
  end
end
