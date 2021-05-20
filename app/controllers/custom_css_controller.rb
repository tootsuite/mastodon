# frozen_string_literal: true

class CustomCssController < ApplicationController
  skip_before_action :store_current_location
  skip_before_action :require_functional!

  before_action :set_cache_headers

  def show
    expires_in 7.days, public: true
    render plain: Setting.custom_css || '', content_type: 'text/css'
  end
end
