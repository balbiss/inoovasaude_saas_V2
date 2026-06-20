class Service < ApplicationRecord
  belongs_to :account
  has_many :appointments, dependent: :nullify

  validates :name, presence: true
  validates :duration_minutes, numericality: { greater_than: 0, allow_nil: true }
  validates :price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
end
