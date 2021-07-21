# frozen_string_literal: true

require 'ipaddr'
require 'socket'
require 'resolv'

# Monkey-patch the HTTP.rb timeout class to avoid using a timeout block
# around the Socket#open method, since we use our own timeout blocks inside
# that method
class HTTP::Timeout::PerOperation
  def connect(socket_class, host, port, nodelay = false)
    @socket = socket_class.open(host, port)
    @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if nodelay
  end
end

class Request
  REQUEST_TARGET = '(request-target)'

  # We enforce a 5s timeout on DNS resolving, 5s timeout on socket opening
  # and 5s timeout on the TLS handshake, meaning the worst case should take
  # about 15s in total
  TIMEOUT = { connect: 5, read: 10, write: 10 }.freeze

  include RoutingHelper

  def initialize(verb, url, **options)
    raise ArgumentError if url.blank?

    @verb        = verb
    @url         = Addressable::URI.parse(url).normalize
    @http_client = options.delete(:http_client)
    @options     = options.merge(socket_class: use_proxy? ? ProxySocket : Socket)
    @options     = @options.merge(Rails.configuration.x.http_client_proxy) if use_proxy?
    @headers     = {}

    raise Mastodon::HostValidationError, 'Instance does not support hidden service connections' if block_hidden_service?

    set_common_headers!
    set_digest! if options.key?(:body)
  end

  def on_behalf_of(account, key_id_format = :uri, sign_with: nil)
    raise ArgumentError, 'account must not be nil' if account.nil?

    @account       = account
    @keypair       = sign_with.present? ? OpenSSL::PKey::RSA.new(sign_with) : @account.keypair
    @key_id_format = key_id_format

    self
  end

  def add_headers(new_headers)
    @headers.merge!(new_headers)
    self
  end

  def perform
    begin
      response = http_client.public_send(@verb, @url.to_s, @options.merge(headers: headers))
    rescue => e
      raise e.class, "#{e.message} on #{@url}", e.backtrace[0]
    end

    begin
      response = response.extend(ClientLimit)

      # If we are using a persistent connection, we have to
      # read every response to be able to move forward at all.
      # However, simply calling #to_s or #flush may not be safe,
      # as the response body, if malicious, could be too big
      # for our memory. So we use the #body_with_limit method
      response.body_with_limit if http_client.persistent?

      yield response if block_given?
    ensure
      http_client.close unless http_client.persistent?
    end
  end

  def headers
    (@account ? @headers.merge('Signature' => signature) : @headers).without(REQUEST_TARGET)
  end

  class << self
    def valid_url?(url)
      begin
        parsed_url = Addressable::URI.parse(url)
      rescue Addressable::URI::InvalidURIError
        return false
      end

      %w(http https).include?(parsed_url.scheme) && parsed_url.host.present?
    end

    def http_client
      HTTP.use(:auto_inflate).timeout(TIMEOUT.dup).follow(max_hops: 2)
    end
  end

  private

  def set_common_headers!
    @headers[REQUEST_TARGET]    = "#{@verb} #{@url.path}"
    @headers['User-Agent']      = Mastodon::Version.user_agent
    @headers['Host']            = @url.host
    @headers['Date']            = Time.now.utc.httpdate
    @headers['Accept-Encoding'] = 'gzip' if @verb != :head
  end

  def set_digest!
    @headers['Digest'] = "SHA-256=#{Digest::SHA256.base64digest(@options[:body])}"
  end

  def signature
    algorithm = 'rsa-sha256'
    signature = Base64.strict_encode64(@keypair.sign(OpenSSL::Digest.new('SHA256'), signed_string))

    "keyId=\"#{key_id}\",algorithm=\"#{algorithm}\",headers=\"#{signed_headers.keys.join(' ').downcase}\",signature=\"#{signature}\""
  end

  def signed_string
    signed_headers.map { |key, value| "#{key.downcase}: #{value}" }.join("\n")
  end

  def signed_headers
    @headers.without('User-Agent', 'Accept-Encoding')
  end

  def key_id
    case @key_id_format
    when :acct
      @account.to_webfinger_s
    when :uri
      [ActivityPub::TagManager.instance.uri_for(@account), '#main-key'].join
    end
  end

  def http_client
    @http_client ||= Request.http_client
  end

  def use_proxy?
    Rails.configuration.x.http_client_proxy.present?
  end

  def block_hidden_service?
    !Rails.configuration.x.access_to_hidden_service && /\.(onion|i2p)$/.match?(@url.host)
  end

  module ClientLimit
    def body_with_limit(limit = 1.megabyte)
      raise Mastodon::LengthValidationError if content_length.present? && content_length > limit

      if charset.nil?
        encoding = Encoding::BINARY
      else
        begin
          encoding = Encoding.find(charset)
        rescue ArgumentError
          encoding = Encoding::BINARY
        end
      end

      contents = String.new(encoding: encoding)

      while (chunk = readpartial)
        contents << chunk
        chunk.clear

        raise Mastodon::LengthValidationError if contents.bytesize > limit
      end

      contents
    end
  end

  class Socket < TCPSocket
    class << self
      def open(host, *args)
        outer_e = nil
        port    = args.first

        addresses = []
        begin
          addresses = [IPAddr.new(host)]
        rescue IPAddr::InvalidAddressError
          Resolv::DNS.open do |dns|
            dns.timeouts = 5
            addresses = dns.getaddresses(host).take(2)
          end
        end

        socks = []
        addr_by_socket = {}

        addresses.each do |address|
          begin
            check_private_address(address, host)

            sock     = ::Socket.new(address.is_a?(Resolv::IPv6) ? ::Socket::AF_INET6 : ::Socket::AF_INET, ::Socket::SOCK_STREAM, 0)
            sockaddr = ::Socket.pack_sockaddr_in(port, address.to_s)

            sock.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, 1)

            sock.connect_nonblock(sockaddr)

            # If that hasn't raised an exception, we somehow managed to connect
            # immediately, close pending sockets and return immediately
            socks.each(&:close)
            return sock
          rescue IO::WaitWritable
            socks << sock
            addr_by_socket[sock] = sockaddr
          rescue => e
            outer_e = e
          end
        end

        until socks.empty?
          _, available_socks, = IO.select(nil, socks, nil, Request::TIMEOUT[:connect])

          if available_socks.nil?
            socks.each(&:close)
            raise HTTP::TimeoutError, "Connect timed out after #{Request::TIMEOUT[:connect]} seconds"
          end

          available_socks.each do |sock|
            socks.delete(sock)

            begin
              sock.connect_nonblock(addr_by_socket[sock])
            rescue Errno::EISCONN
              # Do nothing
            rescue => e
              sock.close
              outer_e = e
              next
            end

            socks.each(&:close)
            return sock
          end
        end

        if outer_e
          raise outer_e
        else
          raise SocketError, "No address for #{host}"
        end
      end

      alias new open

      def check_private_address(address, host)
        addr = IPAddr.new(address.to_s)
        return if private_address_exceptions.any? { |range| range.include?(addr) }
        raise Mastodon::PrivateNetworkAddressError.new(host) if PrivateAddressCheck.private_address?(addr)
      end

      def private_address_exceptions
        @private_address_exceptions = begin
          (ENV['ALLOWED_PRIVATE_ADDRESSES'] || '').split(',').map { |addr| IPAddr.new(addr) }
        end
      end
    end
  end

  class ProxySocket < Socket
    class << self
      def check_private_address(_address)
        # Accept connections to private addresses as HTTP proxies will usually
        # be on local addresses
        nil
      end
    end
  end

  private_constant :ClientLimit, :Socket, :ProxySocket
end
