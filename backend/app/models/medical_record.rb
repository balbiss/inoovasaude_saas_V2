class MedicalRecord < ApplicationRecord
  belongs_to :account
  belongs_to :patient, class_name: 'Contact'
  belongs_to :professional, optional: true
  belongs_to :appointment, optional: true
  belongs_to :recorded_by, class_name: 'User', optional: true
end
