class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :duration_minutes
      t.decimal :price, precision: 10, scale: 2
      t.string :category
      t.string :status, default: 'active'
      t.timestamps
    end

  end
end
