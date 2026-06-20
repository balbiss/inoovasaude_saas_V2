class Professional < ApplicationRecord
  belongs_to :account
  has_many :appointments, dependent: :nullify
  has_many :medical_records, dependent: :destroy

  validates :name, presence: true
  validates :specialty, presence: true

  SPECIALTIES = %w[
    Médico Dentista Psicólogo Fisioterapeuta Nutricionista
    Esteticista Enfermeiro Fonoaudiólogo Terapeuta Outro
  ].freeze
end
