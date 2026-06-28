class AddBookingFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :booking_enabled, :boolean, default: false, null: false
    add_column :accounts, :booking_slug, :string
    add_index :accounts, :booking_slug, unique: true
  end
end
