# ============================================================================
# FILE: app/services/bitcoin_rpc.rb
# ============================================================================
class BitcoinRpc
  class Error < StandardError; end
  class RetriableError < Error; end
  class InsufficientFundsError < Error; end
  
  class << self
    def new_address
      call_rpc('getnewaddress')
    end
    
    def validate_address(address)
      call_rpc('validateaddress', [address])
    end
    
    def get_balance
      call_rpc('getbalance')
    end
    
    def send_payment(address, satoshi_amount)
      balance_satoshi = (get_balance * Bitcoin::SATOSHI_TO_BTC).to_i
      
      if balance_satoshi >= satoshi_amount + AppConfig.bitcoin_fee
        btc_amount = satoshi_amount / Bitcoin::SATOSHI_TO_BTC.to_f
        call_rpc('sendtoaddress', [address, btc_amount])
      else
        Rails.logger.error "Insufficient funds: balance=#{balance_satoshi}, needed=#{satoshi_amount + AppConfig.bitcoin_fee}"
        nil
      end
    end
    
    private
    
    def call_rpc(method, params = [])
      response = connection.post do |req|
        req.body = {
          jsonrpc: '1.0',
          id: 'doshi',
          method: method,
          params: params
        }.to_json
      end
      
      handle_response(response)
      
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      Rails.logger.error "Bitcoin RPC connection error: #{e.message}"
      raise RetriableError, "Connection to Bitcoin node failed: #{e.message}"
      
    rescue StandardError => e
      Rails.logger.error "Bitcoin RPC error: #{e.message}"
      raise Error, "Bitcoin RPC call failed: #{e.message}"
    end
    
    def handle_response(response)
      if response.success?
        body = JSON.parse(response.body)
        
        if body['error']
          error_msg = body['error']['message']
          Rails.logger.error "Bitcoin RPC error: #{error_msg}"
          
          # Retry on certain errors
          if error_msg.match?(/insufficient funds/i)
            raise InsufficientFundsError, error_msg
          elsif error_msg.match?(/loading|warming up/i)
            raise RetriableError, error_msg
          else
            raise Error, error_msg
          end
        end
        
        body['result']
      else
        raise Error, "HTTP #{response.status}: #{response.body}"
      end
    end
    
    def connection
      @connection ||= Faraday.new(
        url: AppConfig.bitcoin_url,
        headers: { 'Content-Type' => 'application/json' }
      ) do |f|
        f.request :authorization, :basic, AppConfig.bitcoin_user, AppConfig.bitcoin_password
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end
  end
end
