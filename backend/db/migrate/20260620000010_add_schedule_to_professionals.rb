class AddScheduleToProfessionals < ActiveRecord::Migration[8.1]
  def change
    add_column :professionals, :consultation_duration, :integer, default: 30
    add_column :professionals, :schedule, :jsonb, default: {
      segunda: { active: true,  start: '08:00', end: '18:00' },
      terca:   { active: true,  start: '08:00', end: '18:00' },
      quarta:  { active: true,  start: '08:00', end: '18:00' },
      quinta:  { active: true,  start: '08:00', end: '18:00' },
      sexta:   { active: true,  start: '08:00', end: '17:00' },
      sabado:  { active: false, start: '08:00', end: '12:00' },
      domingo: { active: false, start: '08:00', end: '12:00' }
    }
    add_column :professionals, :lunch_break, :jsonb, default: { active: true, start: '12:00', end: '13:00' }
    add_column :professionals, :blocked_dates, :jsonb, default: []
  end
end
