# frozen_string_literal: true

module AdminExportControllerConcern
  extend ActiveSupport::Concern

  private

  def send_export_file
    respond_to do |format|
      format.csv { send_data export_data, filename: export_filename }
    end
  end

  def export_data
    raise 'Override in controller'
  end

  def export_filename
    raise 'Override in controller'
  end

  def set_dummy_import!
    @import = Admin::Import.new
  end

  def import_params
    params.require(:admin_import).permit(:data)
  end

  def import_data
    Paperclip.io_adapters.for(@import.data).read
  end

  def parse_import_data!(default_headers)
    data = CSV.parse(import_data, headers: true)
    data = CSV.parse(import_data, headers: default_headers) unless data.headers&.first&.strip&.include?(default_headers[0])
    @data = data.reject(&:blank?)
  end
end
