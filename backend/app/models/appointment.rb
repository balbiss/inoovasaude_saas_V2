class Appointment < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :professional, optional: true
  belongs_to :service, optional: true
  belongs_to :user, optional: true
  has_one :medical_record, dependent: :destroy

  after_create_commit :schedule_confirmation

  FUNNEL_STAGES = %w[novo_paciente agendado compareceu retorno].freeze

  private

  def schedule_confirmation
    AppointmentConfirmationJob.perform_later(id)
  end
end
