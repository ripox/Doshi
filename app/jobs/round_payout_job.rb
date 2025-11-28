# ============================================================================
# FILE: app/jobs/round_payout_job.rb
# ============================================================================
class RoundPayoutJob < ApplicationJob
  queue_as :default
  
  retry_on BitcoinRpc::RetriableError, wait: 5.minutes, attempts: 10
  
  def perform(round)
    # Mark job as not existing at start
    round.update!(job_exists: false)
    
    payout_ratio = 1 + (round.roi / 100.0)
    
    round.deposits.pending_payout.find_each do |deposit|
      payout_amount = (deposit.amount * payout_ratio).to_i
      
      # Check if round has enough in pot to pay this deposit
      break unless round.pot >= payout_amount
      
      # Attempt to send payment
      txid = BitcoinRpc.send_payment(deposit.payout_address, payout_amount)
      
      if txid
        deposit.update!(
          paid: true,
          payout_txid: txid
        )
        
        round.update!(pot: round.pot - payout_amount)
        
        Rails.logger.info "Paid #{deposit.btc_payout_amount} BTC to #{deposit.payout_address} (txid: #{txid})"
      else
        # Not enough balance, stop processing
        Rails.logger.warn "Insufficient balance to pay deposit #{deposit.id}"
        break
      end
    end
    
    # If round has expired, trigger end payout
    if round.expired?
      round.mark_expired!
    end
    
  rescue BitcoinRpc::RetriableError => e
    # Mark job as existing so we know it's retrying
    round.update!(job_exists: true)
    Rails.logger.warn "Bitcoin RPC error, retrying: #{e.message}"
    raise # Re-raise to trigger retry
    
  rescue StandardError => e
    Rails.logger.error "Error in RoundPayoutJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Don't re-raise, let job fail
  end
end
