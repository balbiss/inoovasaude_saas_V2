class AppointmentsController < ApplicationController
  before_action :set_appointment, only: %i[ show update destroy ]

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
    # Try to use current_user's account, fallback to first account or 1 if not available
    account = current_user&.account || Account.first || Account.new(id: 1)
    
    @appointment = Appointment.new(appointment_params)
    @appointment.account_id ||= account.id
    @appointment.user_id ||= current_user.id

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
