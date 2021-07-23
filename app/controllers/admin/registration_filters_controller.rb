# frozen_string_literal: true

module Admin
  class RegistrationFiltersController < BaseController
    before_action :set_registration_filter, only: [:edit, :update, :destroy]

    def index
      authorize :registration_filter, :index?
      @registration_filters = RegistrationFilter.order(id: :desc).page(params[:page])
    end

    def new
      authorize :registration_filter, :create?
      @registration_filter = RegistrationFilter.new
    end

    def create
      authorize :registration_filter, :create?

      @registration_filter = RegistrationFilter.new(resource_params)

      if @registration_filter.save
        log_action :create, @registration_filter

        redirect_to admin_registration_filters_path, notice: I18n.t('admin.registration_filters.created_msg')
      else
        render :new
      end
    end

    def edit
      authorize @registration_filter, :update?
    end

    def update
      authorize @registration_filter, :update?
      if @registration_filter.update(resource_params)
        log_action :update, @registration_filter

        redirect_to admin_registration_filters_path, notice: I18n.t('admin.registration_filters.updated_msg')
      else
        render action: :edit
      end
    end

    def destroy
      authorize @registration_filter, :destroy?
      @registration_filter.destroy!
      log_action :destroy, @registration_filter
      redirect_to admin_registration_filters_path, notice: I18n.t('admin.registration_filters.destroyed_msg')
    end

    private

    def set_registration_filter
      @registration_filter = RegistrationFilter.find(params[:id])
    end

    def resource_params
      params.require(:registration_filter).permit(:phrase, :type, :whole_word)
    end
  end
end
