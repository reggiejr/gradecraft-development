GradeCraft::Application.configure do
  config.action_controller.default_url_options = { :host => 'www.gradecraft.com' }
  config.action_controller.perform_caching = true
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'
  config.action_dispatch.default_headers = { 'X-Frame-Options' => 'ALLOWALL' }
  config.action_mailer.default_url_options = { :host => 'www.gradecraft.com' }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    :authentication => :plain,
    :address => 'smtp.mandrillapp.com',
    :port => 587,
    :domain => 'www.gradecraft.com',
    :user_name => ENV['MANDRILL_USERNAME'],
    :password => ENV['MANDRILL_PASSWORD']
  }
  config.active_support.deprecation = :notify
  config.assets.compile = false
  config.assets.precompile += %w( vendor/modernizr.js )
  config.assets.compress = true
  config.assets.css_compressor = :sass
  config.assets.digest = true
  config.assets.js_compressor = Uglifier.new(mangle: false) if defined? Uglifier
  config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
  config.assets.precompile += %w( .svg .eot .woff .ttf )
  config.cache_classes = true
  config.cache_store = :dalli_store, ENV['MEMCACHED_URL'], { :namespace => 'gradecraft_production', :expires_in => 1.day, :compress => true }
  config.consider_all_requests_local = false
  config.eager_load = true
  config.i18n.fallbacks = true
  config.log_formatter = ::Logger::Formatter.new
  config.log_level = :info
  config.serve_static_assets = false
  config.session_store :active_record_store, :expire_after => 60.minutes
end

Sidekiq.configure_server do |config|
  config.redis = { :url => ENV['REDIS_URL'], :namespace => 'gradecraft_production' }
end

Sidekiq.configure_client do |config|
  config.redis = { :url => ENV['REDIS_URL'], :namespace => 'gradecraft_production' }
end

CarrierWave.configure do |config|
  config.storage = :fog
end
