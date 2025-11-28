# ============================================================================
# FILE: app/jobs/round_end_payout_job.rb
# ============================================================================
class RoundEndPayoutJob < ApplicationJob
  queue_as :default
  
  retry_on BitcoinRpc::RetriableError, wait: 5.minutes, attempts: 10
  
  def perform(round)
    confirmed_deposits = round.confirmed_deposits.to_a
    
    return if confirmed_deposits.empty?
    
    if confirmed_deposits.size > 1
      # Pay remaining pot to first depositor (minus house fee)
      first_deposit = confirmed_deposits.first
      pot_payout = (round.pot * (1 - round.house_pot_fee / 100.0)).to_i
      
      if pot_payout > 0
        BitcoinRpc.send_payment(first_deposit.payout_address, pot_payout)
        Rails.logger.info "Paid pot of #{round.btc_pot} BTC to first depositor: #{first_deposit.payout_address}"
      end
      
      # Pay jackpot to last depositor
      last_deposit = confirmed_deposits.last
      jackpot_amount = round.jackpot.to_i
      
      if jackpot_amount > 0
        BitcoinRpc.send_payment(last_deposit.payout_address, jackpot_amount)
        Rails.logger.info "Paid jackpot of #{round.btc_jackpot} BTC to last depositor: #{last_deposit.payout_address}"
      end
      
    else
      # Only one deposit - refund everything
      single_deposit = confirmed_deposits.first
      BitcoinRpc.send_payment(single_deposit.payout_address, round.total_deposits)
      Rails.logger.info "Refunded #{round.btc_total_deposits} BTC to sole depositor: #{single_deposit.payout_address}"
    end
    
  rescue BitcoinRpc::RetriableError => e
    Rails.logger.warn "Bitcoin RPC error in end payout, retrying: #{e.message}"
    raise # Re-raise to trigger retry
    
  rescue StandardError => e
    Rails.logger.error "Error in RoundEndPayoutJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
