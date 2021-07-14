Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true
  config.action_controller.asset_host      = ENV['CDN_HOST'] if ENV['CDN_HOST'].present?

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  ActiveSupport::Logger.new(STDOUT).tap do |logger|
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Compress JavaScripts and CSS.
  # config.assets.js_compressor = Uglifier.new(mangle: false)
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Allow to specify public IP of reverse proxy if it's needed
  config.action_dispatch.trusted_proxies = ENV['TRUSTED_PROXY_IP'].split.map { |item| IPAddr.new(item) } if ENV['TRUSTED_PROXY_IP'].present?

  config.force_ssl = true
  config.ssl_options = {
    redirect: {
      exclude: -> request { request.path.start_with?('/health') || request.headers["Host"].end_with?('.onion') }
    }
  }

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Use a different cache store in production.
  config.cache_store = :redis_cache_store, REDIS_CACHE_PARAMS

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # English when a translation cannot be found).
  config.i18n.fallbacks = [:en]

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Better log formatting
  config.lograge.enabled = true

  config.lograge.custom_payload do |controller|
    if controller.respond_to?(:signed_request?) && controller.signed_request?
      { key: controller.signature_key_id }
    end
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.action_mailer.perform_caching = false

  # E-mails
  outgoing_email_address = ENV.fetch('SMTP_FROM_ADDRESS', 'notifications@localhost')
  outgoing_mail_domain   = Mail::Address.new(outgoing_email_address).domain
  config.action_mailer.default_options = {
    from: outgoing_email_address,
    reply_to: ENV['SMTP_REPLY_TO'],
    'Message-ID': -> { "<#{Mail.random_tag}@#{outgoing_mail_domain}>" },
  }

  config.action_mailer.smtp_settings = {
    :port                 => ENV['SMTP_PORT'],
    :address              => ENV['SMTP_SERVER'],
    :user_name            => ENV['SMTP_LOGIN'].presence,
    :password             => ENV['SMTP_PASSWORD'].presence,
    :domain               => ENV['SMTP_DOMAIN'] || ENV['LOCAL_DOMAIN'],
    :authentication       => ENV['SMTP_AUTH_METHOD'] == 'none' ? nil : ENV['SMTP_AUTH_METHOD'] || :plain,
    :ca_file              => ENV['SMTP_CA_FILE'].presence || '/etc/ssl/certs/ca-certificates.crt',
    :openssl_verify_mode  => ENV['SMTP_OPENSSL_VERIFY_MODE'],
    :enable_starttls_auto => ENV['SMTP_ENABLE_STARTTLS_AUTO'] || true,
    :tls                  => ENV['SMTP_TLS'].presence,
    :ssl                  => ENV['SMTP_SSL'].presence,
  }

  config.action_mailer.delivery_method = ENV.fetch('SMTP_DELIVERY_METHOD', 'smtp').to_sym

  config.action_dispatch.default_headers = {
    'Server'                 => 'Mastodon',
    'X-Frame-Options'        => 'DENY',
    'X-Content-Type-Options' => 'nosniff',
    'X-XSS-Protection'       => '1; mode=block',
    'Permissions-Policy'     => 'interest-cohort=()',
  }

  config.x.otp_secret = ENV.fetch('OTP_SECRET')
end
