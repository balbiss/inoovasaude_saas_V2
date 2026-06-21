class AppointmentStatusNotificationJob < ApplicationJob
  queue_as :default

  MESSAGES = {
    'confirmado' => lambda { |name, date, time|
      "✅ Olá, #{name}! Sua consulta está confirmada.\n\n📅 Data: #{date}\n🕐 Horário: #{time}\n\nAguardamos você! 😊"
    },
    'compareceu' => lambda { |name, _date, _time|
      "Olá, #{name}! Obrigado por comparecer à sua consulta. 😊\n\nEsperamos que tudo tenha corrido bem. Conte conosco sempre que precisar!"
    },
    'nao_compareceu' => lambda { |name, date, time|
      "Olá, #{name}! 👋 Notamos que você não pôde comparecer à consulta de #{date} às #{time}.\n\nEntre em contato para remarcar. Estamos à disposição!"
    },
    'cancelado' => lambda { |name, date, time|
      "Olá, #{name}! Sua consulta de #{date} às #{time} foi cancelada.\n\nPara remarcar, entre em contato conosco. Estamos à disposição! 💙"
    },
    'retorno' => lambda { |name, date, time|
      "✅ Olá, #{name}! Seu retorno foi confirmado.\n\n📅 Data: #{date}\n🕐 Horário: #{time}\n\nAté breve! 👋"
    }
  }.freeze

  def perform(appointment_id, old_status, new_status)
    return unless MESSAGES.key?(new_status)

    appointment = Appointment.includes(:contact, :professional, :service).find_by(id: appointment_id)
    return unless appointment
    return if appointment.contact&.phone.blank?

    inbox = appointment.account.inboxes.first
    return unless inbox

    contact     = appointment.contact
    name        = contact.first_name.presence || contact.name || 'Paciente'
    date_str    = appointment.appointment_date&.strftime('%d/%m/%Y') || '—'
    time_str    = appointment.start_time || '—'

    message = MESSAGES[new_status].call(name, date_str, time_str)
    WhatsappBaileysService.new(inbox).send_message(contact.phone, message)
  rescue => e
    Rails.logger.error "[AppointmentStatusNotificationJob] #{e.message}"
  end
end
