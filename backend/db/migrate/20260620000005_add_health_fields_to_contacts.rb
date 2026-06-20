class AddHealthFieldsToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :blood_type, :string
    add_column :contacts, :allergies, :text
    add_column :contacts, :health_notes, :text
    add_column :contacts, :health_plan, :string
    add_column :contacts, :health_plan_number, :string
    add_column :contacts, :medical_history, :text
    add_column :contacts, :funnel_stage, :string, default: 'novo_paciente'

    remove_column :contacts, :intention, :string if column_exists?(:contacts, :intention)
    remove_column :contacts, :gross_income, :decimal if column_exists?(:contacts, :gross_income)
    remove_column :contacts, :down_payment, :decimal if column_exists?(:contacts, :down_payment)
    remove_column :contacts, :fgts_balance, :decimal if column_exists?(:contacts, :fgts_balance)
    remove_column :contacts, :dependents, :integer if column_exists?(:contacts, :dependents)
  end
end
