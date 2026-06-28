class AppointmentConfirmationJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.includes(:contact, :professional, :service).find_by(id: appointment_id)
    return unless appointment
    return if appointment.confirmation_sent_at.present?

    inbox = appointment.account.inboxes.first
    return unless inbox

    contact = appointment.contact
    professional = appointment.professional
    service = appointment.service

    phone = normalize_phone(contact&.phone)
    return if phone.blank?

    date_str = appointment.appointment_date&.strftime('%d/%m/%Y')
    time_str = appointment.start_time

    message = build_message(contact, professional, service, date_str, time_str)

    sent = send_whatsapp(inbox, phone, message)
    appointment.update_columns(confirmation_sent_at: Time.current) if sent

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

      Qualquer dúvida, é só nos chamar aqui. Até lá! 😊
    MSG
  end

  def normalize_phone(phone)
    return nil if phone.blank?
    digits = phone.gsub(/\D/, '')
    digits = "55#{digits}" if digits.length <= 11 && !digits.start_with?('55')
    digits
  end

  # Tries to find the real WhatsApp JID, handling the Brazilian 8/9-digit format difference
  def resolve_jid(svc, digits)
    jid = svc.resolve_jid(digits)
    return jid if jid.present?

    # 13 digits (55 + DDD + 9 + 8): try without the leading 9
    if digits.start_with?('55') && digits.length == 13
      ddd    = digits[2..3]
      number = digits[4..]
      if number.start_with?('9') && number.length == 9
        alt = "55#{ddd}#{number[1..]}"
        jid = svc.resolve_jid(alt)
        return jid if jid.present?
      end
    end

    # 12 digits (55 + DDD + 8): try with leading 9
    if digits.start_with?('55') && digits.length == 12
      ddd    = digits[2..3]
      number = digits[4..]
      if number.length == 8
        alt = "55#{ddd}9#{number}"
        jid = svc.resolve_jid(alt)
        return jid if jid.present?
      end
    end

    nil
  end

  def send_whatsapp(inbox, phone, message)
    svc = WhatsappBaileysService.new(inbox)
    jid = resolve_jid(svc, phone)
    unless jid.present?
      Rails.logger.warn "[AppointmentConfirmationJob] Número #{phone} não encontrado no WhatsApp"
      return false
    end
    result = svc.send_message(jid, message)
    result.present?
  rescue => e
    Rails.logger.error "[AppointmentConfirmationJob] Falha ao enviar WhatsApp: #{e.message}"
    false
  end
end
