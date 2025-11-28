# ============================================================================
# FILE: app/models/jackpot_deposit.rb
# ============================================================================
# == Schema Information
#
# Table name: jackpot_deposits
#
#  id           :bigint           not null, primary key
#  round_id     :bigint           not null
#  amount       :bigint           not null
#  deposit_txid :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
class JackpotDeposit < ApplicationRecord
  belongs_to :round
  
  validates :deposit_txid, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  
  def btc_amount
    amount / Bitcoin::SATOSHI_TO_BTC.to_f
  end
end