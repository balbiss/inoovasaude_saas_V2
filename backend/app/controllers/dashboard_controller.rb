class DashboardController < ApplicationController
  def index
    is_owner   = current_user.secretaria? || current_user.admin? || current_user.has_permission?('view_all_contacts')
    account    = current_user.account
    uid        = current_user.id
    today      = Date.current

    # Scopes filtrados por papel
    # Corretor: contatos derivados das conversas atribuídas a ele (não user_id do contato)
    if is_owner
      contacts_scope = account.contacts
      conv_scope     = account.conversations
      appt_scope     = Appointment.where(account_id: account.id)
    else
      my_contact_ids = account.conversations.where(user_id: uid).pluck(:contact_id).uniq
      contacts_scope = account.contacts.where(id: my_contact_ids)
      conv_scope     = account.conversations.where(user_id: uid)
      # Agendamentos atribuídos ao corretor OU criados pela IA para seus contatos
      appt_scope     = Appointment.where(account_id: account.id)
                                  .where('user_id = ? OR (user_id IS NULL AND contact_id IN (?))', uid, my_contact_ids.presence || [0])
    end

    total_contacts  = contacts_scope.count
    funnel_counts   = contacts_scope.group(:funnel_stage).count

    kanban = {
      novo_paciente: funnel_counts['novo_paciente'] || 0,
      agendado:      funnel_counts['agendado']      || 0,
      compareceu:    funnel_counts['compareceu']    || 0,
      retorno:       funnel_counts['retorno']       || 0
    }

    retorno_count = funnel_counts['retorno'] || 0

    # Batch conversations: 1 GROUP BY instead of 2 COUNTs
    conv_status   = conv_scope.group(:status).count
    conv_open     = conv_status['open']     || 0
    conv_resolved = conv_status['resolved'] || 0
    conv_today    = conv_scope.where(created_at: today.beginning_of_day..today.end_of_day).count

    com_atendente_tag = account.tags.find_by(name: 'com_atendente')
    with_human = com_atendente_tag ? conv_scope.joins(:conversation_tags)
      .where(conversation_tags: { tag_id: com_atendente_tag.id }).count : 0

    # Appointments: batch status into GROUP BY, derive total from it (no extra query)
    appt_status   = appt_scope.group(:status).count
    appt_total    = appt_status.values.sum
    appt_today    = appt_scope.where(appointment_date: today).count
    appt_upcoming = appt_scope.where('appointment_date >= ?', today).where.not(status: 'cancelado').count
    appt_done     = appt_status['compareceu'] || 0

    leads_by_source = contacts_scope.where.not(source: [nil, '']).group(:source).count

    # Consultas do dia
    today_appointments = appt_scope
      .where(appointment_date: today)
      .includes(:contact, :professional, :service)
      .order(Arel.sql("NULLIF(start_time, '') ASC NULLS LAST"))
      .limit(50)
      .map do |appt|
        {
          id:            appt.id,
          start_time:    appt.start_time,
          end_time:      appt.end_time,
          status:        appt.status,
          contact_name:  appt.contact&.name.presence || appt.contact&.phone || 'Desconhecido',
          contact_phone: appt.contact&.phone,
          professional:  appt.professional&.name,
          service:       appt.service&.name,
        }
      end

    # Leads atribuídos hoje — conversas novas atribuídas a este usuário (ou a qualquer um, se dono)
    today_conv_scope = is_owner \
      ? account.conversations.where(created_at: today.beginning_of_day..today.end_of_day) \
      : account.conversations.where(user_id: uid, created_at: today.beginning_of_day..today.end_of_day)

    today_assigned_leads = today_conv_scope
      .includes(:contact, :user)
      .order(created_at: :desc)
      .limit(20)
      .map do |conv|
        c = conv.contact
        next unless c
        {
          conversation_id: conv.id,
          contact_name:    c.name.presence || c.phone || 'Desconhecido',
          contact_phone:   c.phone,
          funnel_stage:    c.funnel_stage,
          health_notes:    c.health_notes,
          assigned_to:     conv.user_id == uid ? nil : conv.user&.first_name,
          created_at:      conv.created_at
        }
      end.compact

    render json: {
      is_owner: is_owner,
      kpis: {
        total_contacts:  total_contacts,
        retorno_count:   retorno_count,
        kanban:          kanban,
        conversations:   { open: conv_open, resolved: conv_resolved, today: conv_today, with_human: with_human },
        appointments:    { total: appt_total, today: appt_today, upcoming: appt_upcoming, done: appt_done }
      },
      leads_by_source:      leads_by_source,
      today_assigned_leads: today_assigned_leads,
      today_appointments:   today_appointments
    }
  end
end
