# ============================================================================
# FILE: app/services/bitcoin_alerter.rb
# ============================================================================
class BitcoinAlerter
  class Error < StandardError; end
  
  class << self
    def subscribe(address, expiration_count)
      response = connection.post do |req|
        req.body = {
          address: address,
          callback_url: AppConfig.deposit_report_url,
          expiration_count: expiration_count,
          herpaderpderp: 'big_ass_smiggy'
        }
      end
      
      handle_response(response)
      
    rescue Faraday::Error => e
      Rails.logger.error "Bitcoin Alerter error: #{e.message}"
      raise Error, "Failed to subscribe address: #{e.message}"
    end
    
    private
    
    def handle_response(response)
      if response.success?
        body = JSON.parse(response.body)
        
        unless body['status'] == 'success'
          raise Error, "Alerter subscription failed: #{body.inspect}"
        end
        
        true
      else
        raise Error, "HTTP #{response.status}: #{response.body}"
      end
    end
    
    def connection
      @connection ||= Faraday.new(
        url: AppConfig.alerter_url,
        ssl: { verify: false } # Note: In production, use proper SSL verification
      ) do |f|
        f.request :url_encoded
        f.response :json
        f.adapter Faraday.default_adapter
        
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end
  end
end