class RoundsController < ApplicationController
  before_action :set_round, only: [:show]
  
  # GET /rounds
  def index
    @rounds = Round.active.by_recent_activity.includes(:deposits)
    @round = Round.new
  end
  
  # GET /rounds/all
  def all
    @rounds = Round.all.by_recent_activity.includes(:deposits)
    @round = Round.new
    render :index
  end
  
  # GET /rounds/:id
  def show
    @deposits = @round.confirmed_deposits.includes(:round)
  end
  
  # GET /rounds/new
  def new
    @round = Round.new
  end
  
  # POST /rounds
  def create
    @round = Round.new(round_params)
    
    if @round.save
      # Create first deposit for the round creator
      @deposit = @round.deposits.new(
        payout_address: @round.first_payout_address,
        ip: request.remote_ip,
        user_agent: request.user_agent
      )
      
      # Skip round state validation for the initial deposit
      @deposit.skip_round_validation = true
      
      if @deposit.save
        redirect_to landing_round_deposit_path(@round, @deposit), 
                    notice: 'Round was successfully created.'
      else
        @round.destroy
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_round
    @round = Round.find(params[:id])
  end
  
  def round_params
    params.require(:round).permit(
      :name,
      :roi,
      :jackpot_percent,
      :minimum_deposit,
      :maximum_deposit,
      :expiration,
      :decay,
      :first_payout_address
    ).tap do |whitelisted|
      # Convert BTC to satoshis
      if whitelisted[:minimum_deposit].present?
        whitelisted[:minimum_deposit] = (whitelisted[:minimum_deposit].to_f * Bitcoin::SATOSHI_TO_BTC).to_i
      end
      
      if whitelisted[:maximum_deposit].present?
        whitelisted[:maximum_deposit] = (whitelisted[:maximum_deposit].to_f * Bitcoin::SATOSHI_TO_BTC).to_i
      end
      
      # Convert hours to seconds
      if whitelisted[:expiration].present?
        whitelisted[:expiration] = (whitelisted[:expiration].to_f * 3600).to_i
      end
    end
  end
end
