# ============================================================================
# FILE: app/models/round.rb
# ============================================================================
# == Schema Information
#
# Table name: rounds
#
#  id                   :bigint           not null, primary key
#  name                 :string           not null
#  roi                  :integer          not null
#  jackpot_percent      :integer          not null
#  pot                  :bigint           default(0)
#  minimum_deposit      :bigint           not null
#  maximum_deposit      :bigint           not null
#  expiration           :integer          not null
#  decay                :integer          not null
#  state                :integer          default(0)
#  house_initial_fee    :integer          not null
#  house_pot_fee        :integer          not null
#  house_deposit_fee    :integer          not null
#  total_deposits       :bigint           default(0)
#  first_payout_address :string           not null
#  job_exists           :boolean          default(false)
#  jackpot_address      :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class Round < ApplicationRecord
  # Enums for state
  enum :state, { pending: 0, active: 1, expired: 2 }, prefix: true
  
  # Associations
  has_many :deposits, dependent: :destroy
  has_many :jackpot_deposits, dependent: :destroy
  has_many :confirmed_deposits, -> { where(confirmed: true).order(confirmed_at: :asc) }, 
           class_name: 'Deposit'
  
  # Callbacks
  before_validation :generate_jackpot_address, on: :create
  before_validation :set_default_values, on: :create
  after_create :subscribe_jackpot_address
  
  # Validations
  validates :name, presence: true, 
                   uniqueness: true, 
                   length: { maximum: 21 }
  
  validates :roi, presence: true,
                  inclusion: { in: 1..200 }
  
  validates :decay, presence: true,
                    inclusion: { in: 0..50 }
  
  validates :expiration, presence: true,
                         numericality: { 
                         greater_than_or_equal_to: 1,
                         less_than_or_equal_to: 345600 
                       }
  
  validates :minimum_deposit, presence: true,
                              numericality: { 
                                greater_than_or_equal_to: 10_000_000,
                                less_than_or_equal_to: 100_000_000_000 
                              }
  
  validates :maximum_deposit, presence: true,
                              numericality: { 
                                greater_than_or_equal_to: ->(round) { round.minimum_deposit },
                                less_than_or_equal_to: 100_000_000_000 
                              }
  
  validates :jackpot_percent, presence: true,
                              inclusion: { 
                                in: ->(round) { 1..(100 - round.house_initial_fee) } 
                              }
  
  validates :jackpot_address, presence: true, uniqueness: true
  validates :first_payout_address, presence: true
  
  validate :first_payout_address_is_valid, on: :create
  
  # Scopes
  scope :active, -> { where(state: :active) }
  scope :by_recent_activity, -> { 
    left_joins(:deposits)
      .where(deposits: { confirmed: true })
      .group('rounds.id')
      .order('MAX(deposits.confirmed_at) DESC NULLS LAST')
  }
  
  # Instance methods
  def last_deposit_time
    confirmed_deposits.maximum(:confirmed_at) || 10.years.ago
  end
  
  def jackpot
    (total_deposits * jackpot_percent / 100.0) + jackpot_deposits.sum(:amount)
  end
  
  def time_remaining
    return nil unless state_active?
    [(last_deposit_time + expiration.seconds - Time.current).to_i, 0].max
  end
  
  def expired?
    state_active? && time_remaining&.zero?
  end
  
  def mark_expired!
    update!(state: :expired)
    RoundEndPayoutJob.perform_later(self)
  end
  
  def btc_minimum_deposit
    minimum_deposit / Bitcoin::SATOSHI_TO_BTC.to_f
  end
  
  def btc_maximum_deposit
    maximum_deposit / Bitcoin::SATOSHI_TO_BTC.to_f
  end
  
  def btc_total_deposits
    total_deposits / Bitcoin::SATOSHI_TO_BTC.to_f
  end
  
  def btc_jackpot
    jackpot / Bitcoin::SATOSHI_TO_BTC.to_f
  end
  
  def btc_pot
    pot / Bitcoin::SATOSHI_TO_BTC.to_f
  end
  
  def expiration_hours
    expiration / 3600.0
  end
  
  def time_remaining_hours
    time_remaining / 3600.0 if time_remaining
  end
  
  private
  
  def set_default_values
    self.pot ||= 0
    self.state ||= :pending
    self.job_exists ||= false
    self.house_initial_fee ||= AppConfig.house_initial_fee
    self.house_pot_fee ||= AppConfig.house_pot_fee
    self.house_deposit_fee ||= AppConfig.house_deposit_fee
    self.total_deposits ||= 0
  end
  
  def generate_jackpot_address
    self.jackpot_address = BitcoinRpc.new_address
  end
  
  def subscribe_jackpot_address
    BitcoinAlerter.subscribe(jackpot_address, -1)
  rescue StandardError => e
    Rails.logger.error "Failed to subscribe jackpot address: #{e.message}"
    errors.add(:base, "Failed to setup Bitcoin monitoring")
    raise ActiveRecord::Rollback
  end
  
  def first_payout_address_is_valid
    result = BitcoinRpc.validate_address(first_payout_address)
    unless result['isvalid']
      errors.add(:first_payout_address, 'is not a valid Bitcoin address')
    end
  rescue StandardError => e
    errors.add(:first_payout_address, 'could not be validated')
  end
end
