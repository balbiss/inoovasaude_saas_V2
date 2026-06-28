class AppointmentFinalReminderJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.includes(:contact, :professional, :service).find_by(id: appointment_id)
    return unless appointment
    return if appointment.contact&.phone.blank?
    return if appointment.status.in?(%w[cancelado nao_compareceu])

    inbox = appointment.account.inboxes.first
    return unless inbox

    contact      = appointment.contact
    professional = appointment.professional
    service      = appointment.service
    time_str     = appointment.start_time

    patient_name = contact.first_name.presence || contact.name

    message = <<~MSG.strip
      ⏰ Lembrete: sua consulta é hoje em 4 horas!

      👤 #{patient_name}, não esqueça:
      🕐 Horário: #{time_str}
      👨‍⚕️ Profissional: #{professional&.name || 'A definir'}
      🏥 Serviço: #{service&.name || 'Consulta'}

      Te esperamos! Se precisar remarcar, entre em contato agora.
    MSG

    WhatsappBaileysService.new(inbox).send_message(contact.phone, message)
  rescue => e
    Rails.logger.error "[AppointmentFinalReminderJob] Falha ao enviar WhatsApp: #{e.message}"
  end
end
