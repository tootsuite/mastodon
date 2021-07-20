# frozen_string_literal: true

require 'csv'

module Admin
  class ExportDomainAllowsController < BaseController
    include AdminExportControllerConcern

    before_action :set_dummy_import!, only: [:new]

    ROWS_PROCESSING_LIMIT = 20_000

    def new
      authorize :domain_allow, :create?
    end

    def export
      authorize :instance, :index?
      send_export_file
    end

    def import
      authorize :domain_allow, :create?
      begin
        @import = Admin::Import.new(import_params)
        parse_import_data!(export_headers)

        @data.take(ROWS_PROCESSING_LIMIT).each do |row|
          domain = row['#domain'].strip
          next if DomainAllow.allowed?(domain)

          domain_allow = DomainAllow.new(domain: domain)
          log_action :create, domain_allow if domain_allow.save
        end
        flash[:notice] = I18n.t('admin.domain_allows.created_msg')
      rescue ActionController::ParameterMissing
        flash[:error] = I18n.t('admin.export_domain_allows.no_file')
      end
      redirect_to admin_instances_path
    end

    private

    def export_filename
      'domain_allows.csv'
    end

    def export_headers
      %w(#domain)
    end

    def export_data
      CSV.generate(headers: export_headers, write_headers: true) do |content|
        DomainAllow.allowed_domains.each do |instance|
          content << [instance.domain]
        end
      end
    end
  end
end
