# frozen_string_literal: true

class AdminImportValidator < ActiveModel::Validator
  FIRST_HEADER = '#domain'

  def validate(import)
    return if import.type.blank? || import.data.blank?

    # We parse because newlines could be part of individual rows. This
    # runs on create so we should be reading the local file here before
    # it is uploaded to object storage or moved anywhere...
    csv_data = CSV.parse(import.data.queued_for_write[:original].read)

    row_count  = csv_data.size
    row_count -= 1 if csv_data.first&.first == FIRST_HEADER

    import.errors.add(:data, I18n.t('imports.errors.over_rows_processing_limit', count: Admin::DomainBlocksController::ROWS_PROCESSING_LIMIT)) if row_count > Admin::DomainBlocksController::ROWS_PROCESSING_LIMIT
  end
end
