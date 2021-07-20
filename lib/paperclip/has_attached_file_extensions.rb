# frozen_string_literal: true

module Paperclip
  module HasAttachedFileExtensions
    # Rails 6 doesn't support (or silently ignore) :on
    def add_active_record_callbacks
      name = @name
      @klass.send(:after_save) { send(name).send(:save) }
      @klass.send(:before_destroy) { send(name).send(:queue_all_for_delete) }
      @klass.send(:after_destroy) { send(name).send(:flush_deletes) }
    end
  end
end

Paperclip::HasAttachedFile.prepend(Paperclip::HasAttachedFileExtensions)
