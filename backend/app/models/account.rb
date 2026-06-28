class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :inboxes, dependent: :destroy
  has_many :professionals, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :medical_records, dependent: :destroy
  has_many :support_tickets, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :tags, dependent: :destroy

  before_create :set_trial_period
  before_create :generate_portal_token
  before_create :generate_booking_slug

  def active_subscription?
    return false if ['blocked', 'canceled', 'unpaid'].include?(subscription_status)
    subscription_status == 'active' || (trial_ends_at.present? && trial_ends_at > Time.current)
  end

  def booking_url
    return nil if booking_slug.blank?
    public_host = ENV['FRONTEND_URL'].presence || ENV['PUBLIC_URL'].presence || 'http://localhost:5173'
    "#{public_host}/agendar/#{booking_slug}"
  end

  private

  def set_trial_period
    self.trial_ends_at ||= 7.days.from_now
  end

  def generate_portal_token
    self.portal_token ||= SecureRandom.hex(16)
  end

  def generate_booking_slug
    return if booking_slug.present?
    base = name.to_s.downcase
                .unicode_normalize(:nfd)
                .gsub(/[^a-z0-9\s]/i, '')
                .strip
                .gsub(/\s+/, '-')
    base = 'clinica' if base.blank?
    slug = base
    suffix = 1
    while Account.exists?(booking_slug: slug)
      slug = "#{base}-#{suffix}"
      suffix += 1
    end
    self.booking_slug = slug
  end
end
