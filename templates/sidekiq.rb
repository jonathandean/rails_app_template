Sidekiq.default_worker_options = { 'backtrace' => true }

Sidekiq.configure_server do |config|
  config.redis = {
    ssl_params: {
      # https://stackoverflow.com/questions/65834575/how-to-enable-tls-for-redis-6-on-sidekiq
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
      url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0')
    }
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    ssl_params: {
      # https://stackoverflow.com/questions/65834575/how-to-enable-tls-for-redis-6-on-sidekiq
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
      url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0')
    }
  }
end