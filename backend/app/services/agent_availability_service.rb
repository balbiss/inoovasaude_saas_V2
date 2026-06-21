class AgentAvailabilityService
  DAY_MAP = %w[domingo segunda terca quarta quinta sexta sabado].freeze

  def initialize(professional)
    @professional = professional
  end

  def available_slots(date)
    date = Date.parse(date.to_s) rescue return []
    day_key = DAY_MAP[date.wday]

    schedule  = (@professional.schedule || {}).with_indifferent_access
    day       = schedule[day_key]
    return [] unless day.present? && day['active'].to_s == 'true'

    blocked = Array(@professional.blocked_dates || [])
    return [] if blocked.map(&:to_s).include?(date.to_s)

    duration = (@professional.consultation_duration || 30).to_i

    work_start = parse_time(date, day['start'])
    work_end   = parse_time(date, day['end'])
    return [] unless work_start && work_end

    lunch  = (@professional.lunch_break || {}).with_indifferent_access
    has_lunch = lunch['active'].to_s == 'true'
    l_start = has_lunch ? parse_time(date, lunch['start']) : nil
    l_end   = has_lunch ? parse_time(date, lunch['end'])   : nil

    booked = Appointment
      .where(professional_id: @professional.id, appointment_date: date)
      .where.not(status: %w[cancelado nao_compareceu])
      .pluck(:start_time)
      .compact
      .filter_map { |t| parse_time(date, t) }

    slots  = []
    cursor = work_start

    while cursor + duration.minutes <= work_end
      slot_end = cursor + duration.minutes
      in_lunch  = l_start && l_end && cursor < l_end && slot_end > l_start
      conflict  = booked.any? { |b| cursor < b + duration.minutes && slot_end > b }
      slots << cursor.strftime('%H:%M') unless in_lunch || conflict
      cursor += duration.minutes
    end

    slots
  end

  private

  def parse_time(date, str)
    return nil if str.blank?
    Time.parse("#{date} #{str}")
  rescue
    nil
  end
end
