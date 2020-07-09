# frozen_string_literal: true

module TwoFactorAuthenticationConcern
  extend ActiveSupport::Concern

  included do
    prepend_before_action :authenticate_with_two_factor, if: :two_factor_enabled?, only: [:create]
  end

  def two_factor_enabled?
    find_user&.two_factor_enabled?
  end

  def valid_webauthn_credential?(user, webauthn_credential)
    user_credential = user.webauthn_credentials.find_by!(external_id: webauthn_credential.id)

    begin
      webauthn_credential.verify(
        session[:webauthn_challenge],
        public_key: user_credential.public_key,
        sign_count: user_credential.sign_count
      )

      user_credential.update!(sign_count: webauthn_credential.sign_count)
    rescue WebAuthn::Error
      false
    end
  end

  def valid_otp_attempt?(user)
    user.validate_and_consume_otp!(user_params[:otp_attempt]) ||
      user.invalidate_otp_backup_code!(user_params[:otp_attempt])
  rescue OpenSSL::Cipher::CipherError
    false
  end

  def authenticate_with_two_factor
    user = self.resource = find_user

    if user.webauthn_enabled? && user_params[:credential].present? && session[:attempt_user_id]
      authenticate_with_two_factor_via_webauthn(user)
    elsif user_params[:otp_attempt].present? && session[:attempt_user_id]
      authenticate_with_two_factor_via_otp(user)
    elsif user.present? && user.external_or_valid_password?(user_params[:password])
      prompt_for_two_factor(user)
    end
  end

  def authenticate_with_two_factor_via_webauthn(user)
    webauthn_credential = WebAuthn::Credential.from_get(user_params[:credential])

    if valid_webauthn_credential?(user, webauthn_credential)
      session.delete(:attempt_user_id)
      remember_me(user)
      sign_in(user)
      render json: { redirect_path: root_path }, status: :ok
    else
      flash.now[:alert] = t('webauthn_credentials.invalid_credential')
      render json: {}, status: :unauthorized
    end
  end

  def authenticate_with_two_factor_via_otp(user)
    if valid_otp_attempt?(user)
      session.delete(:attempt_user_id)
      remember_me(user)
      sign_in(user)
    else
      flash.now[:alert] = I18n.t('users.invalid_otp_token')
      prompt_for_two_factor(user)
    end
  end

  def prompt_for_two_factor(user)
    set_locale do
      session[:attempt_user_id] = user.id
      @body_classes = 'lighter'
      @webauthn_enabled = user.webauthn_enabled?
      @scheme_type = if user.webauthn_enabled? && user_params[:otp_attempt].blank?
                       'webauthn'
                     else
                       'totp'
                     end
      render :two_factor
    end
  end
end
