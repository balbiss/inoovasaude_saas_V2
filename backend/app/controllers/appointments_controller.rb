class AppointmentsController < ApplicationController
  before_action :set_appointment, only: %i[ show update destroy update_status ]

  # GET /appointments/report
  def report
    scope  = base_scope.includes(:contact, :professional, :service, :user)
    period = parse_period(params[:period])
    scoped = scope.where(appointment_date: period)

    by_status = {
      agendado:   scoped.where(status: 'agendado').count,
      confirmado: scoped.where(status: 'confirmado').count,
      compareceu: scoped.where(status: 'compareceu').count,
      cancelado:  scoped.where(status: 'cancelado').count
    }

    by_professional = if owner?
      current_user.account.professionals.map do |prof|
        prof_scope = scoped.where(professional_id: prof.id)
        {
          id:        prof.id,
          name:      prof.name,
          specialty: prof.specialty,
          total:     prof_scope.count,
          done:      prof_scope.where(status: 'compareceu').count
        }
      end
    else
      nil
    end

    appointments = scoped.order(appointment_date: :asc).map do |a|
      {
        id:               a.id,
        status:           a.status,
        appointment_date: a.appointment_date,
        start_time:       a.start_time,
        end_time:         a.end_time,
        contact:          { name: a.contact&.name, phone: a.contact&.phone },
        professional:     { name: a.professional&.name, specialty: a.professional&.specialty },
        service:          { name: a.service&.name },
        agent:            a.user ? "#{a.user.first_name} #{a.user.last_name}".strip : nil
      }
    end

    render json: {
      is_owner:        owner?,
      period:          { start: period.first, end: period.last },
      total:           scoped.count,
      by_status:       by_status,
      by_professional: by_professional,
      appointments:    appointments
    }
  end

  # GET /appointments/export
  def export
    scope  = base_scope.includes(:contact, :professional, :service, :user)
    period = parse_period(params[:period])
    rows   = scope.where(appointment_date: period).order(appointment_date: :asc)

    headers_row = ['Data', 'Início', 'Fim', 'Paciente', 'Telefone', 'Profissional', 'Serviço', 'Atendente', 'Status']
    csv_rows = rows.map do |a|
      [
        a.appointment_date&.strftime('%d/%m/%Y'),
        a.start_time, a.end_time,
        a.contact&.name, a.contact&.phone,
        a.professional&.name,
        a.service&.name,
        a.user ? "#{a.user.first_name} #{a.user.last_name}".strip : 'N/A',
        a.status
      ]
    end

    csv = ([headers_row] + csv_rows).map { |r| r.map { |c| "\"#{c.to_s.gsub('"','""')}\"" }.join(';') }.join("\n")
    send_data "\xEF\xBB\xBF" + csv,
      filename: "consultas_#{Date.current}.csv",
      type: 'text/csv; charset=utf-8',
      disposition: 'attachment'
  end

  # GET /appointments
  def index
    scope = base_scope.includes(:contact, :professional, :service)

    scope = scope.where(professional_id: params[:professional_id]) if params[:professional_id]
    scope = scope.where(appointment_date: params[:date]) if params[:date]

    render json: scope.order(appointment_date: :desc, start_time: :asc).as_json(include: {
      contact:      { only: %i[id name phone] },
      professional: { only: %i[id name specialty] },
      service:      { only: %i[id name duration_minutes] }
    })
  end

  # GET /appointments/1
  def show
    render json: @appointment.as_json(include: {
      contact:      { only: %i[id name phone] },
      professional: { only: %i[id name specialty] },
      service:      { only: %i[id name duration_minutes price] }
    })
  end

  # POST /appointments
  def create
    account = current_user.account

    @appointment = Appointment.new(appointment_params)
    @appointment.account_id ||= account.id
    @appointment.user_id    ||= current_user.id

    if @appointment.contact_id.present?
      contact_appointments = account.appointments.where(contact_id: @appointment.contact_id)

      # Regra 1: bloquear duplo agendamento (consulta já pendente)
      if account.block_double_booking != false
        pending = contact_appointments.where(status: %w[agendado confirmado]).exists?
        if pending
          return render json: {
            errors: ['Este paciente já tem uma consulta pendente (agendada ou confirmada). Cancele ou finalize a consulta atual antes de agendar uma nova.']
          }, status: :unprocessable_entity
        end
      end

      # Regra 2: prazo de retorno a partir da última consulta realizada
      if @appointment.status == 'retorno'
        retorno_days = (account.retorno_days || 30).to_i
        last_done = contact_appointments
          .where(status: 'compareceu')
          .order(appointment_date: :desc)
          .first

        if last_done.nil?
          return render json: {
            errors: ['Não há consulta anterior registrada como realizada para este paciente. O retorno só pode ser agendado após uma consulta concluída.']
          }, status: :unprocessable_entity
        end

        days_since = (Date.current - last_done.appointment_date.to_date).to_i
        if days_since > retorno_days
          deadline = (last_done.appointment_date.to_date + retorno_days.days).strftime('%d/%m/%Y')
          return render json: {
            errors: ["O prazo de retorno de #{retorno_days} dias expirou em #{deadline}. Agende uma nova consulta regular."]
          }, status: :unprocessable_entity
        end
      end
    end

    if @appointment.save
      render json: @appointment, status: :created, location: @appointment
    else
      render json: @appointment.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /appointments/1
  def update
    if @appointment.update(appointment_params)
      render json: @appointment
    else
      render json: @appointment.errors, status: :unprocessable_entity
    end
  end

  # PATCH /appointments/1/update_status
  def update_status
    valid_statuses = %w[agendado confirmado compareceu nao_compareceu cancelado retorno]
    new_status = params[:status].to_s
    return render json: { error: 'Status inválido' }, status: :unprocessable_entity unless valid_statuses.include?(new_status)

    old_status = @appointment.status
    @appointment.update_columns(status: new_status, updated_at: Time.current)
    AppointmentStatusNotificationJob.perform_later(@appointment.id, old_status, new_status) if old_status != new_status
    render json: { id: @appointment.id, status: new_status }
  end

  # DELETE /appointments/1
  def destroy
    @appointment.destroy!
  end

  private
    def owner?
      current_user.secretaria? || current_user.admin?
    end

    def base_scope
      account = current_user.account
      if owner?
        Appointment.where(account_id: account.id)
      else
        Appointment.where(account_id: account.id, user_id: current_user.id)
      end
    end

    def parse_period(preset)
      case preset
      when 'today' then Date.current.beginning_of_day..Date.current.end_of_day
      when 'week'  then Date.current.beginning_of_week..Date.current.end_of_week
      when 'month' then Date.current.beginning_of_month..Date.current.end_of_month
      when 'custom'
        s = Date.parse(params[:start_date]) rescue Date.current.beginning_of_month
        e = Date.parse(params[:end_date])   rescue Date.current
        s.beginning_of_day..e.end_of_day
      else
        Date.current.beginning_of_month..Date.current.end_of_month
      end
    end

    def set_appointment
      @appointment = Appointment.find(params[:id])
    end

    def appointment_params
      params.require(:appointment).permit(
        :account_id, :contact_id, :professional_id, :service_id, :user_id,
        :status, :appointment_date, :start_time, :end_time,
        :consultation_type, :notes
      )
    end
end
