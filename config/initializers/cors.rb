# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'

    resource '/.well-known/*',
      headers: :any,
      methods: [:get],
      credentials: false
    resource '/@:username',
      headers: :any,
      methods: [:get],
      credentials: false
    resource '/users/:username',
      headers: :any,
      methods: [:get],
      credentials: false
    resource '/@:username/:id',
      headers: [],
      methods: [:get],
      credentials: false
    resource '/users/:username/statuses/:id',
      headers: [],
      methods: [:get],
      credentials: false
    resource '/api/*',
      headers: :any,
      methods: [:post, :put, :delete, :get, :patch, :options],
      credentials: false,
      expose: ['Link', 'X-RateLimit-Reset', 'X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-Request-Id']
    resource '/oauth/token',
      headers: :any,
      methods: [:post],
      credentials: false
  end
end
