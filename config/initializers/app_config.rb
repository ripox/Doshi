# ============================================================================
# FILE: config/initializers/app_config.rb
# ============================================================================
class AppConfig
  class << self
    def config
      @config ||= begin
        file_path = Rails.root.join('config', 'app_config.yml')
        yaml_config = YAML.load_file(file_path, aliases: true)
        erb_config = ERB.new(yaml_config.to_yaml).result
        parsed_config = YAML.safe_load(erb_config, permitted_classes: [], aliases: true)
        parsed_config[Rails.env].with_indifferent_access
      end
    end
    
    def method_missing(method, *args)
      config[method] || super
    end
    
    def respond_to_missing?(method, include_private = false)
      config.key?(method) || super
    end
  end
end

module Bitcoin
  SATOSHI_TO_BTC = 100_000_000
end
