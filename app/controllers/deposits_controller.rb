# ============================================================================
# FILE: app/controllers/deposits_controller.rb
# ============================================================================
class DepositsController < ApplicationController
  before_action :set_round, except: [:report]
  before_action :set_deposit, only: [:landing]
  skip_before_action :verify_authenticity_token, only: [:report]
  
  # GET /rounds/:round_id/deposits
  def index
    # Security check - only allow with secret parameter
    return head :forbidden unless params[:herpaderp] == 'smiggy'
    
    @deposits = @round.confirmed_deposits
    render json: @deposits
  end
  
  # GET /rounds/:round_id/deposits/new
  def new
    unless @round.state_active?
      redirect_to @round, alert: 'This round is not currently accepting deposits.'
      return
    end
    
    @deposit = @round.deposits.build
  end
  
  # POST /rounds/:round_id/deposits
  def create
    @deposit = @round.deposits.build(deposit_params)
    @deposit.ip = request.remote_ip
    @deposit.user_agent = request.user_agent
    
    if @deposit.save
      redirect_to landing_round_deposit_path(@round, @deposit), 
                  notice: 'Deposit address created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  # GET /rounds/:round_id/deposits/:id/landing
  def landing
    # Landing page shows deposit address and instructions
  end
  
  # POST /deposits/report
  # Webhook callback from Bitcoin alerter service
  def report
    # Verify request is from trusted source
    unless request_from_trusted_source?
      Rails.logger.warn "Unauthorized deposit report from #{request.remote_ip}"
      head :forbidden
      return
    end
    
    address = params[:address]
    amount = params[:amount].to_i
    txid = params[:tx_hash]
    
    # Check if this is a deposit address
    if (deposit = Deposit.find_by(deposit_address: address))
      deposit.confirm_deposit!(bitcoin_amount: amount, txid: txid)
      render json: { status: 'success', type: 'deposit' }
      
    # Check if this is a jackpot address
    elsif (round = Round.find_by(jackpot_address: address))
      unless JackpotDeposit.exists?(round: round, deposit_txid: txid)
        JackpotDeposit.create!(
          round: round,
          amount: (amount * Bitcoin::SATOSHI_TO_BTC).to_i,
          deposit_txid: txid
        )
      end
      render json: { status: 'success', type: 'jackpot' }
      
    else
      Rails.logger.warn "Unknown address in deposit report: #{address}"
      render json: { status: 'unknown_address' }, status: :not_found
    end
    
  rescue StandardError => e
    Rails.logger.error "Error processing deposit report: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { status: 'error', message: e.message }, status: :internal_server_error
  end
  
  private
  
  def set_round
    @round = Round.find(params[:round_id])
  end
  
  def set_deposit
    @deposit = @round.deposits.find(params[:id])
  end
  
  def deposit_params
    params.require(:deposit).permit(:payout_address)
  end
  
  def request_from_trusted_source?
    remote_ip = request.remote_ip
    
    # Check X-Forwarded-For header
    if (forwarded = request.headers['HTTP_X_FORWARDED_FOR'])
      remote_ip = forwarded.split(',').first.strip
    end
    
    remote_ip == AppConfig.deposit_report_ip
  end
end