module Public
  class BookingsController < ApplicationController
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :check_subscription_access!, raise: false
    skip_before_action :verify_authenticity_token, raise: false

    before_action :load_account

    def show
      professionals = @account.professionals.where(status: 'active').map do |p|
        {
          id: p.id,
          name: p.name,
          specialty: p.specialty,
          consultation_duration: p.consultation_duration || 30,
          accepted_plans: p.accepted_plans || [],
          accepts_particular: p.accepts_particular != false,
          schedule: p.schedule || {}
        }
      end

      services = @account.services.where(status: 'active').map do |s|
        { id: s.id, name: s.name, duration_minutes: s.duration_minutes, price: s.price }
      end

      render json: {
        clinic_name: @account.name,
        return_block_days: @account.retorno_days || 0,
        block_double_booking: @account.block_double_booking != false,
        professionals: professionals,
        services: services
      }
    end

    def slots
      professional = @account.professionals.find_by(id: params[:professional_id])
      return render json: { error: 'Profissional não encontrado' }, status: :not_found unless professional

      date = Date.parse(params[:date].to_s) rescue nil
      return render json: { error: 'Data inválida' }, status: :bad_request unless date
      return render json: { slots: [] } if date < Date.current

      # Blocked date?
      if professional.blocked_dates&.include?(date.to_s)
        return render json: { slots: [] }
      end

      day_names = %w[domingo segunda terca quarta quinta sexta sabado]
      day_name  = day_names[date.wday]
      day_sched = professional.schedule&.dig(day_name)

      return render json: { slots: [] } unless day_sched&.dig('active')

      duration = professional.consultation_duration || 30
      all_slots = generate_slots(day_sched['start'], day_sched['end'], duration, professional.lunch_break)

      booked = @account.appointments
        .where(professional_id: professional.id, appointment_date: date)
        .where.not(status: %w[cancelado nao_compareceu])
        .pluck(:start_time)

      available = all_slots.reject { |s| booked.include?(s) }
      render json: { slots: available, duration: duration }
    end

    def create
      cpf    = params[:cpf].to_s.gsub(/\D/, '')
      name   = params[:name].to_s.strip
      phone  = params[:phone].to_s.strip
      date   = params[:appointment_date].to_s
      time   = params[:start_time].to_s
      plan   = params[:health_plan].to_s.strip
      cons_type = params[:consultation_type].to_s.strip

      return render_error('Nome completo é obrigatório.')    if name.blank?
      return render_error('CPF é obrigatório.')             if cpf.blank?
      return render_error('Data é obrigatória.')            if date.blank?
      return render_error('Horário é obrigatório.')         if time.blank?

      professional = @account.professionals.find_by(id: params[:professional_id])
      return render_error('Profissional inválido.') unless professional

      service = params[:service_id].present? ? @account.services.find_by(id: params[:service_id]) : nil

      # Find or create contact by CPF
      contact = @account.contacts.find_by(cpf: cpf)
      if contact.nil?
        contact = @account.contacts.new(
          name: name, phone: phone.presence, cpf: cpf,
          health_plan: plan.presence, source: 'agendamento_online'
        )
        return render_error(contact.errors.full_messages.join(', ')) unless contact.save
      end

      # Double booking check
      if @account.block_double_booking != false
        existing = @account.appointments
          .where(contact_id: contact.id, status: %w[agendado confirmado])
          .where('appointment_date >= ?', Date.current)
          .first

        if existing
          date_fmt = existing.appointment_date.strftime('%d/%m/%Y')
          return render_error("Você já tem uma consulta agendada para #{date_fmt} às #{existing.start_time}. " \
                              "Finalize ou cancele antes de agendar uma nova.")
        end
      end

      # Return block check
      retorno_days = @account.retorno_days.to_i
      if retorno_days > 0
        last_done = @account.appointments
          .where(contact_id: contact.id, status: %w[compareceu retorno])
          .where('appointment_date >= ?', retorno_days.days.ago.to_date)
          .order(appointment_date: :desc)
          .first

        if last_done
          next_date = last_done.appointment_date + retorno_days.days
          return render_error("Agendamento bloqueado. Você se consultou em #{last_done.appointment_date.strftime('%d/%m/%Y')}. " \
                              "Retorno disponível a partir de #{next_date.strftime('%d/%m/%Y')} (#{retorno_days} dias de intervalo).")
        end
      end

      # Calculate end time
      duration = professional.consultation_duration || 30
      start_dt = Time.parse("#{date} #{time}") rescue nil
      return render_error('Horário inválido.') unless start_dt
      end_time_str = (start_dt + duration.minutes).strftime('%H:%M')

      appointment = @account.appointments.new(
        contact: contact,
        professional: professional,
        service: service,
        appointment_date: date,
        start_time: time,
        end_time: end_time_str,
        status: 'agendado',
        consultation_type: cons_type.presence,
        notes: plan.present? ? "Convênio: #{plan}" : nil
      )

      if appointment.save
        AppointmentConfirmationJob.perform_later(appointment.id)
        ActionCable.server.broadcast('conversations_channel', {
          event: 'appointment_created',
          appointment_id: appointment.id
        })

        render json: {
          message: 'Agendamento realizado com sucesso!',
          appointment: {
            id: appointment.id,
            date: appointment.appointment_date.strftime('%d/%m/%Y'),
            time: appointment.start_time,
            professional: professional.name,
            service: service&.name
          }
        }, status: :created
      else
        render_error(appointment.errors.full_messages.join(', '))
      end
    end

    private

    def load_account
      @account = Account.find_by(booking_slug: params[:slug])
      unless @account&.booking_enabled?
        render json: { error: 'Página de agendamento não encontrada ou desativada.' }, status: :not_found
      end
    end

    def generate_slots(start_t, end_t, duration, lunch_break)
      slots  = []
      cur    = parse_min(start_t)
      finish = parse_min(end_t)

      lb_start = lb_end = nil
      if lunch_break&.dig('active')
        lb_start = parse_min(lunch_break['start'])
        lb_end   = parse_min(lunch_break['end'])
      end

      while cur + duration <= finish
        unless lb_start && cur >= lb_start && cur < lb_end
          slots << format_min(cur)
        end
        cur += duration
      end
      slots
    end

    def parse_min(str)
      h, m = str.to_s.split(':').map(&:to_i)
      h * 60 + m
    end

    def format_min(m)
      '%02d:%02d' % [m / 60, m % 60]
    end

    def render_error(msg)
      render json: { error: msg }, status: :unprocessable_entity
    end
  end
end
