require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative '../lib/exceptions'
require_relative '../lib/enumerable'
require_relative '../lib/sanitize_ext/sanitize_config'
require_relative '../lib/redis/namespace_extensions'
require_relative '../lib/paperclip/schema_extensions'
require_relative '../lib/paperclip/validation_extensions'
require_relative '../lib/paperclip/url_generator_extensions'
require_relative '../lib/paperclip/attachment_extensions'
require_relative '../lib/paperclip/media_type_spoof_detector_extensions'
require_relative '../lib/paperclip/lazy_thumbnail'
require_relative '../lib/paperclip/gif_transcoder'
require_relative '../lib/paperclip/transcoder'
require_relative '../lib/paperclip/type_corrector'
require_relative '../lib/paperclip/response_with_limit_adapter'
require_relative '../lib/terrapin/multi_pipe_extensions'
require_relative '../lib/mastodon/snowflake'
require_relative '../lib/mastodon/version'
require_relative '../lib/devise/two_factor_ldap_authenticatable'
require_relative '../lib/devise/two_factor_pam_authenticatable'
require_relative '../lib/chewy/strategy/custom_sidekiq'
require_relative '../lib/webpacker/manifest_extensions'
require_relative '../lib/webpacker/helper_extensions'
require_relative '../lib/action_dispatch/cookie_jar_extensions'
require_relative '../lib/rails/engine_extensions'
require_relative '../lib/active_record/database_tasks_extensions'
require_relative '../lib/active_record/batches'

Dotenv::Railtie.load

Bundler.require(:pam_authentication) if ENV['PAM_ENABLED'] == 'true'

require_relative '../lib/mastodon/redis_config'

module Mastodon
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1
    config.add_autoload_paths_to_load_path = false

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # All translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.available_locales = [
      :af,
      :ar,
      :ast,
      :bg,
      :bn,
      :br,
      :ca,
      :co,
      :cs,
      :cy,
      :da,
      :de,
      :el,
      :en,
      :eo,
      :es,
      :'es-AR',
      :'es-MX',
      :et,
      :eu,
      :fa,
      :fi,
      :fr,
      :ga,
      :gd,
      :gl,
      :he,
      :hi,
      :hr,
      :hu,
      :hy,
      :id,
      :io,
      :is,
      :it,
      :ja,
      :ka,
      :kab,
      :kk,
      :kn,
      :ko,
      :ku,
      :lt,
      :lv,
      :mk,
      :ml,
      :mr,
      :ms,
      :nl,
      :nn,
      :no,
      :oc,
      :pl,
      :'pt-BR',
      :'pt-PT',
      :ro,
      :ru,
      :sa,
      :sc,
      :sgs,
      :si,
      :sk,
      :sl,
      :sq,
      :sr,
      :'sr-Latn',
      :sv,
      :ta,
      :te,
      :th,
      :tr,
      :uk,
      :ur,
      :vi,
      :zgh,
      :'zh-CN',
      :'zh-HK',
      :'zh-TW',
    ]

    config.i18n.default_locale = ENV['DEFAULT_LOCALE']&.to_sym

    unless config.i18n.available_locales.include?(config.i18n.default_locale)
      config.i18n.default_locale = :en
    end

    # config.paths.add File.join('app', 'api'), glob: File.join('**', '*.rb')
    # config.autoload_paths += Dir[Rails.root.join('app', 'api', '*')]

    config.active_job.queue_adapter = :sidekiq

    config.middleware.use Rack::Attack
    config.middleware.use Rack::Deflater

    config.to_prepare do
      Doorkeeper::AuthorizationsController.layout 'modal'
      Doorkeeper::AuthorizedApplicationsController.layout 'admin'
      Doorkeeper::Application.send :include, ApplicationExtension
      Doorkeeper::AccessToken.send :include, AccessTokenExtension
      Devise::FailureApp.send :include, AbstractController::Callbacks
      Devise::FailureApp.send :include, HttpAcceptLanguage::EasyAccess
      Devise::FailureApp.send :include, Localized
    end
  end
end
