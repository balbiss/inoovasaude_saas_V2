class AddAcceptedPlansToProfessionals < ActiveRecord::Migration[8.1]
  def change
    add_column :professionals, :accepted_plans, :jsonb, default: []
    add_column :professionals, :accepts_particular, :boolean, default: true
  end
end
