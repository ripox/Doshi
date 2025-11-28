class BitcoinRpcMock
  class << self
    def new_address
      # Generate a fake Bitcoin address
      "1#{SecureRandom.hex(16)}#{('A'..'Z').to_a.sample(8).join}"
    end
    
    def validate_address(address)
      # Mock validation - just check if it looks like a Bitcoin address
      {
        'isvalid' => address.to_s.length > 20,
        'address' => address
      }
    end
    
    def get_balance
      # Return a fake balance (10 BTC)
      10.0
    end
    
    def send_payment(address, satoshi_amount)
      # Return a fake transaction ID
      Rails.logger.info "MOCK: Sending #{satoshi_amount} satoshis to #{address}"
      SecureRandom.hex(32)
    end
  end
end
