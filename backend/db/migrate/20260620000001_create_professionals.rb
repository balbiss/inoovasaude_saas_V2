class CreateProfessionals < ActiveRecord::Migration[8.1]
  def change
    create_table :professionals do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :specialty, null: false
      t.string :council_number
      t.string :phone
      t.string :email
      t.text :bio
      t.string :status, default: 'active'
      t.timestamps
    end

    add_index :professionals, :account_id
  end
end
