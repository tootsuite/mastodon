# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Remotable do
  class Foo
    include ActiveSupport::Callbacks

    define_callbacks :save

    def self.after_save(*filters, &blk)
      set_callback(:save, :after, *filters, &blk)
    end

    def initialize
      @attrs = {}
    end

    def [](arg)
      @attrs[arg]
    end

    def []=(arg1, arg2)
      @attrs[arg1] = arg2
    end

    def hoge=(arg); end

    def hoge_file_name; end

    def hoge_file_name=(arg); end

    def has_attribute?(arg); end

    def self.attachment_definitions
      { hoge: nil }
    end
  end

  before do
    class Foo
      include Remotable

      remotable_attachment :hoge, 1.kilobyte
    end
  end

  let(:attribute_name) { "#{hoge}_remote_url".to_sym }
  let(:code)           { 200 }
  let(:file)           { 'filename="foo.txt"' }
  let(:foo)            { Foo.new }
  let(:headers)        { { 'content-disposition' => file } }
  let(:hoge)           { :hoge }
  let(:url)            { 'https://google.com' }

  it 'defines a method #hoge_remote_url=' do
    expect(foo).to respond_to(:hoge_remote_url=)
  end

  it 'defines a method #reset_hoge!' do
    expect(foo).to respond_to(:reset_hoge!)
  end

  it 'defines a method #download_hoge!' do
    expect(foo).to respond_to(:download_hoge!)
  end

  describe '#hoge_remote_url=' do
    before do
      stub_request(:get, url).to_return(status: code, headers: headers)
    end

    it 'always returns its argument' do
      [nil, '', [], {}].each do |arg|
        expect(foo.hoge_remote_url = arg).to be arg
      end
    end

    context 'with an invalid URL' do
      before do
        allow(Addressable::URI).to receive_message_chain(:parse, :normalize).with(url).with(no_args).and_raise(Addressable::URI::InvalidURIError)
      end

      it 'makes no request' do
        foo.hoge_remote_url = url
        expect(a_request(:get, url)).to_not have_been_made
      end
    end

    context 'with scheme that is neither http nor https' do
      let(:url) { 'ftp://google.com' }

      it 'makes no request' do
        foo.hoge_remote_url = url
        expect(a_request(:get, url)).to_not have_been_made
      end
    end

    context 'with relative URL' do
      let(:url) { 'https:///path' }

      it 'makes no request' do
        foo.hoge_remote_url = url
        expect(a_request(:get, url)).to_not have_been_made
      end
    end

    context 'when URL has not changed' do
      it 'makes no request if file is already saved' do
        allow(foo).to receive(:[]).with(attribute_name).and_return(url)
        allow(foo).to receive(:hoge_file_name).and_return('foo.jpg')

        foo.hoge_remote_url = url
        expect(a_request(:get, url)).to_not have_been_made
      end

      it 'makes request if file is not already saved' do
        allow(foo).to receive(:[]).with(attribute_name).and_return(url)
        allow(foo).to receive(:hoge_file_name).and_return(nil)

        foo.hoge_remote_url = url
        expect(a_request(:get, url)).to have_been_made
      end
    end

    context 'when instance has no attribute for URL' do
      before do
        allow(foo).to receive(:has_attribute?).with(attribute_name).and_return(false)
      end

      it 'does not try to write attribute' do
        expect(foo).to_not receive('[]=').with(attribute_name, url)
        foo.hoge_remote_url = url
      end
    end

    context 'when instance has an attribute for URL' do
      before do
        allow(foo).to receive(:has_attribute?).with(attribute_name).and_return(true)
      end

      it 'does not try to write attribute' do
        expect(foo).to receive('[]=').with(attribute_name, url)
        foo.hoge_remote_url = url
      end
    end

    context 'with a valid URL' do
      it 'makes a request' do
        foo.hoge_remote_url = url
        expect(a_request(:get, url)).to have_been_made
      end

      context 'when the response is not successful' do
        let(:code) { 500 }

        it 'does not assign file' do
          expect(foo).not_to receive(:public_send).with("#{hoge}=", any_args)
          expect(foo).not_to receive(:public_send).with("#{hoge}_file_name=", any_args)

          foo.hoge_remote_url = url
        end
      end

      context 'when the response is successful' do
        let(:code) { 200 }

        context 'and contains Content-Disposition header' do
          let(:file)      { 'filename="foo.txt"' }
          let(:headers)   { { 'content-disposition' => file } }

          it 'assigns file' do
            response_with_limit = ResponseWithLimit.new(nil, 0)

            allow(ResponseWithLimit).to receive(:new).with(anything, anything).and_return(response_with_limit)

            expect(foo).to receive(:public_send).with("download_#{hoge}!", url)

            foo.hoge_remote_url = url

            expect(foo).to receive(:public_send).with("#{hoge}=", response_with_limit)

            foo.download_hoge!(url)
          end
        end
      end

      context 'when an error is raised during the request' do
        before do
          stub_request(:get, url).to_raise(error_class)
        end

        error_classes = [
          HTTP::TimeoutError,
          HTTP::ConnectionError,
          OpenSSL::SSL::SSLError,
          Paperclip::Errors::NotIdentifiedByImageMagickError,
          Addressable::URI::InvalidURIError,
        ]

        error_classes.each do |error_class|
          let(:error_class) { error_class }

          it 'calls Rails.logger.debug' do
            expect(Rails.logger).to receive(:debug).with(/^Error fetching remote #{hoge}: /)
            foo.hoge_remote_url = url
          end
        end
      end
    end
  end
end
