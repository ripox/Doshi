# ============================================================================
# FILE: app/models/deposit.rb
# ============================================================================
# == Schema Information
#
# Table name: deposits
#
#  id              :bigint           not null, primary key
#  round_id        :bigint           not null
#  deposit_address :string           not null
#  payout_address  :string           not null
#  confirmed       :boolean          default(false)
#  amount          :bigint
#  ip              :string           not null
#  user_agent      :string
#  payout_txid     :string
#  paid            :boolean          default(false)
#  confirmed_at    :datetime
#  deposit_txid    :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Deposit < ApplicationRecord
  # Associations
  belongs_to :round
  
  # Callbacks
  before_validation :generate_deposit_address, on: :create
  after_create :subscribe_deposit_address
  
# Validations
  validates :deposit_address, presence: true, uniqueness: true
  validates :payout_address, presence: true
  validates :ip, presence: true
  
  validate :addresses_are_valid, on: :create
  validate :round_is_active, on: :create, unless: :skip_round_validation
  validate :amount_in_range, if: :amount?
  
  attr_accessor :skip_round_validation
  
  # Scopes
  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }
  scope :pending_payout, -> { confirmed.unpaid.order(confirmed_at: :asc) }
  
  # Instance methods
  def confirm_deposit!(bitcoin_amount:, txid:)
    return if confirmed?
    
    satoshi_amount = (bitcoin_amount * Bitcoin::SATOSHI_TO_BTC).to_i
    return if satoshi_amount < round.minimum_deposit
    
    capped_amount = [satoshi_amount, round.maximum_deposit].min
    
    transaction do
      update_round_state_if_first_deposit!
      
      deposit_fee = round.state_pending? ? round.house_initial_fee : round.house_deposit_fee
      
      update!(
        amount: capped_amount,
        confirmed: true,
        confirmed_at: Time.current,
 def round_is_active
    unless round.state_active?
      errors.add(:round, 'is not currently active')
    end        deposit_txid: txid
      )
      
      round.update!(
        total_deposits: round.total_deposits + capped_amount,
        pot: round.pot + (capped_amount * (1 - (round.jackpot_percent + deposit_fee) / 100.0)),
        expiration: round.expiration * (1 - (round.decay / 100.0))
      )
      
      enqueue_payout_job_if_needed
    end
    
    Rails.logger.info "Deposit confirmed: #{id} - #{btc_amount} BTC"
  end
  
  def btc_amount
    amount / Bitcoin::SATOSHI_TO_BTC.to_f if amount
  end
  
  def btc_payout_amount
    return nil unless amount
    amount * (1 + round.roi / 100.0) / Bitcoin::SATOSHI_TO_BTC.to_f
  end
  
  def allowed_range
    round.minimum_deposit..round.maximum_deposit
  end
  
  private
  
  def generate_deposit_address
    self.deposit_address = BitcoinRpc.new_address
  end
  
  def subscribe_deposit_address
    BitcoinAlerter.subscribe(deposit_address, 1)
  rescue StandardError => e
    Rails.logger.error "Failed to subscribe deposit address: #{e.message}"
    errors.add(:base, "Failed to setup Bitcoin monitoring")
    raise ActiveRecord::Rollback
  end
  
  def addresses_are_valid
    validate_address(deposit_address, :deposit_address)
    validate_address(payout_address, :payout_address)
  end
  
  def validate_address(address, field)
    return unless address.present?
    
    result = BitcoinRpc.validate_address(address)
    unless result['isvalid']
      errors.add(field, 'is not a valid Bitcoin address')
    end
  rescue StandardError => e
    errors.add(field, 'could not be validated')
  end
  
  def round_is_active
    unless round.state_active?
      errors.add(:round, 'is not currently active')
    end
  end
  
  def amount_in_range
    unless allowed_range.include?(amount)
      errors.add(:amount, "must be between #{round.btc_minimum_deposit} and #{round.btc_maximum_deposit} BTC")
    end
  end
  
  def update_round_state_if_first_deposit!
    if round.state_pending?
      round.update!(state: :active)
    end
  end
  
  def enqueue_payout_job_if_needed
    return if round.job_exists?
    
    round.update!(job_exists: true)
    RoundPayoutJob.perform_later(round)
    Rails.logger.info "Enqueued RoundPayoutJob for round #{round.id}"
  end
end
