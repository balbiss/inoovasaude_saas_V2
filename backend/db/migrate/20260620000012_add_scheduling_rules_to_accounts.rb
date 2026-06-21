class AddSchedulingRulesToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :retorno_days,          :integer, default: 30
    add_column :accounts, :block_double_booking,  :boolean, default: true
  end
end
