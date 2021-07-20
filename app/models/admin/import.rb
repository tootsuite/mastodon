# frozen_string_literal: true

# A non-activerecord helper class for csv upload
class Admin::Import
  extend ActiveModel::Callbacks
  include ActiveModel::Model
  include Paperclip::Glue

  FILE_TYPES = %w(text/plain text/csv application/csv).freeze

  # Paperclip required callbacks
  define_model_callbacks :save, only: [:after]
  define_model_callbacks :commit, only: [:after]
  define_model_callbacks :destroy, only: [:before, :after]

  attr_accessor :data_file_name, :data_content_type

  has_attached_file :data
  validates_attachment_content_type :data, content_type: FILE_TYPES
  validates_attachment_presence :data
  validates_with AdminImportValidator, on: :create

  def save
    run_callbacks :save
  end

  def destroy
    run_callbacks :destroy
  end

  def commit
    run_callbacks :commit
  end
end
