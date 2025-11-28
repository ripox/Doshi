class BitcoinAlerterMock
  class << self
    def subscribe(address, expiration_count)
      Rails.logger.info "MOCK: Subscribed to address #{address} with expiration #{expiration_count}"
      true
    end
  end
end
