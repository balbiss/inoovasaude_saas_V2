class AppointmentConfirmationJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.includes(:contact, :professional, :service).find_by(id: appointment_id)
    return unless appointment
    return if appointment.contact&.phone.blank?
    return if appointment.confirmation_sent_at.present?

    inbox = appointment.account.inboxes.first
    return unless inbox

    contact = appointment.contact
    professional = appointment.professional
    service = appointment.service

    date_str = appointment.appointment_date&.strftime('%d/%m/%Y')
    time_str = appointment.start_time

    message = build_message(contact, professional, service, date_str, time_str)

    send_whatsapp(inbox, contact.phone, message)
    appointment.update_columns(confirmation_sent_at: Time.current)

    # Lembrete 1: dia anterior às 9h (pedindo confirmação)
    day_before_9am = appointment.appointment_date.to_datetime - 1.day + 9.hours
    # Lembrete único: 3 horas antes da consulta
    if appointment.start_time.present?
      appt_datetime = DateTime.parse("#{appointment.appointment_date} #{appointment.start_time}")
      three_hours_before = appt_datetime - 3.hours
      if three_hours_before > Time.current
        AppointmentReminderJob.set(wait_until: three_hours_before)
                              .perform_later(appointment_id)
      end
    end
  end

  private

  def build_message(contact, professional, service, date, time)
    patient_name = contact.first_name.presence || contact.name
    <<~MSG.strip
      Olá, #{patient_name}! 👋
      Sua consulta foi agendada com sucesso! ✅

      📅 Data: #{date}
      🕐 Horário: #{time}
      👨‍⚕️ Profissional: #{professional&.name || 'A definir'}
      🏥 Serviço: #{service&.name || 'Consulta'}

      Para confirmar seu agendamento, responda SIM.
      Para cancelar ou remarcar, entre em contato conosco.
    MSG
  end

  def send_whatsapp(inbox, phone, message)
    WhatsappBaileysService.new(inbox).send_message(phone, message)
  rescue => e
    Rails.logger.error "[AppointmentConfirmationJob] Falha ao enviar WhatsApp: #{e.message}"
  end
end
