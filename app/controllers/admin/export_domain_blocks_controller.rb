# frozen_string_literal: true

require 'csv'

module Admin
  class ExportDomainBlocksController < BaseController
    include AdminExportControllerConcern

    before_action :set_dummy_import!, only: [:new]

    ROWS_PROCESSING_LIMIT = 20_000

    def new
      authorize :domain_block, :create?
    end

    def export
      authorize :instance, :index?
      send_export_file
    end

    def import
      authorize :domain_block, :create?
      begin
        @import = Admin::Import.new(import_params)
        parse_import_data!(export_headers)

        @data.take(ROWS_PROCESSING_LIMIT).each do |row|
          domain = row['#domain'].strip
          next if DomainBlock.rule_for(domain).present?

          domain_block = DomainBlock.new(domain: domain,
                                         severity: row['#severity'].strip,
                                         reject_media: row['#reject_media'].strip,
                                         reject_reports: row['#reject_reports'].strip,
                                         public_comment: row['#public_comment'].strip,
                                         obfuscate: row['#obfuscate'].strip)
          if domain_block.save
            DomainBlockWorker.perform_async(domain_block.id)
            log_action :create, domain_block
          end
        end
        flash[:notice] = I18n.t('admin.domain_blocks.created_msg')
      rescue ActionController::ParameterMissing
        flash[:error] = I18n.t('admin.export_domain_blocks.no_file')
      end
      redirect_to admin_instances_path(limited: '1')
    end

    private

    def export_filename
      'domain_blocks.csv'
    end

    def export_headers
      %w(#domain #severity #reject_media #reject_reports #public_comment #obfuscate)
    end

    def export_data
      CSV.generate(headers: export_headers, write_headers: true) do |content|
        DomainBlock.with_user_facing_limitations.each do |instance|
          content << [instance.domain, instance.severity, instance.reject_media, instance.reject_reports, instance.public_comment, instance.obfuscate]
        end
      end
    end
  end
end
