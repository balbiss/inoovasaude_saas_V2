class AppointmentReminderJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.includes(:contact, :professional, :service).find_by(id: appointment_id)
    return unless appointment
    return if appointment.contact&.phone.blank?
    return if appointment.status.in?(%w[cancelado cancelled])
    return if appointment.reminder_sent_at.present?

    inbox = appointment.account.inboxes.first
    return unless inbox

    contact = appointment.contact
    professional = appointment.professional
    service = appointment.service

    date_str = appointment.appointment_date&.strftime('%d/%m/%Y')
    time_str = appointment.start_time

    message = build_reminder(contact, professional, service, date_str, time_str)

    send_whatsapp(inbox, contact.phone, message)
    appointment.update_columns(reminder_sent_at: Time.current)
  end

  private

  def build_reminder(contact, professional, service, date, time)
    patient_name = contact.first_name.presence || contact.name
    prof_name    = professional&.name || 'nosso profissional'
    serv_name    = service&.name || 'consulta'

    <<~MSG.strip
      Olá, #{patient_name}! 😊

      Passando para lembrar que você tem uma *#{serv_name}* hoje com *#{prof_name}* às *#{time}*.

      Você vai conseguir comparecer? Por favor, me confirme respondendo:

      👉 *SIM* — para confirmar sua presença ✅
      👉 *NÃO* — para cancelar ❌

      Qualquer dúvida é só chamar aqui!
    MSG
  end

  def send_whatsapp(inbox, phone, message)
    WhatsappBaileysService.new(inbox).send_message(phone, message)
  rescue => e
    Rails.logger.error "[AppointmentReminderJob] Falha ao enviar WhatsApp: #{e.message}"
  end
end
