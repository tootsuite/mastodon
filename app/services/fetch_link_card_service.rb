# frozen_string_literal: true

class FetchLinkCardService < BaseService
  URL_PATTERN = %r{
    (#{Twitter::TwitterText::Regex[:valid_url_preceding_chars]})                                                                #   $1 preceding chars
    (                                                                                                                           #   $2 URL
      (https?:\/\/)                                                                                                             #   $3 Protocol (required)
      (#{Twitter::TwitterText::Regex[:valid_domain]})                                                                           #   $4 Domain(s)
      (?::(#{Twitter::TwitterText::Regex[:valid_port_number]}))?                                                                #   $5 Port number (optional)
      (/#{Twitter::TwitterText::Regex[:valid_url_path]}*)?                                                                      #   $6 URL Path and anchor
      (\?#{Twitter::TwitterText::Regex[:valid_url_query_chars]}*#{Twitter::TwitterText::Regex[:valid_url_query_ending_chars]})? #   $7 Query String
    )
  }iox

  def call(status)
    @status = status
    @url    = parse_urls

    return if @url.nil? || @status.preview_cards.any?

    @url = @url.to_s

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        @card = PreviewCard.find_by(url: @url)
        process_url if @card.nil? || @card.updated_at <= 2.weeks.ago || @card.missing_image?
      else
        raise Mastodon::RaceConditionError
      end
    end

    attach_card if @card&.persisted?
  rescue HTTP::Error, OpenSSL::SSL::SSLError, Addressable::URI::InvalidURIError, Mastodon::HostValidationError, Mastodon::LengthValidationError => e
    Rails.logger.debug "Error fetching link #{@url}: #{e}"
    nil
  end

  private

  def process_url
    @card ||= PreviewCard.new(url: @url)

    attempt_oembed || attempt_opengraph
  end

  def html
    return @html if defined?(@html)

    Request.new(:get, @url).add_headers('Accept' => 'text/html', 'User-Agent' => Mastodon::Version.user_agent + ' Bot').perform do |res|
      if res.code == 200 && res.mime_type == 'text/html'
        @html_charset = res.charset
        @html = res.body_with_limit
      else
        @html_charset = nil
        @html = nil
      end
    end
  end

  def attach_card
    @status.preview_cards << @card
    Rails.cache.delete(@status)
  end

  def parse_urls
    if @status.local?
      urls = @status.text.scan(URL_PATTERN).map { |array| Addressable::URI.parse(array[1]).normalize }
    else
      html  = Nokogiri::HTML(@status.text)
      links = html.css('a')
      urls  = links.filter_map { |a| Addressable::URI.parse(a['href']) unless skip_link?(a) }.filter_map(&:normalize)
    end

    urls.reject { |uri| bad_url?(uri) }.first
  end

  def bad_url?(uri)
    # Avoid local instance URLs and invalid URLs
    uri.host.blank? || TagManager.instance.local_url?(uri.to_s) || !%w(http https).include?(uri.scheme)
  end

  # rubocop:disable Naming/MethodParameterName
  def mention_link?(a)
    @status.mentions.any? do |mention|
      a['href'] == ActivityPub::TagManager.instance.url_for(mention.account)
    end
  end

  def skip_link?(a)
    # Avoid links for hashtags and mentions (microformats)
    a['rel']&.include?('tag') || a['class']&.match?(/u-url|h-card/) || mention_link?(a)
  end
  # rubocop:enable Naming/MethodParameterName

  def attempt_oembed
    service         = FetchOEmbedService.new
    url_domain      = Addressable::URI.parse(@url).normalized_host
    cached_endpoint = Rails.cache.read("oembed_endpoint:#{url_domain}")

    embed   = service.call(@url, cached_endpoint: cached_endpoint) unless cached_endpoint.nil?
    embed ||= service.call(@url, html: html) unless html.nil?

    return false if embed.nil?

    url = Addressable::URI.parse(service.endpoint_url)

    @card.type          = embed[:type]
    @card.title         = embed[:title]         || ''
    @card.author_name   = embed[:author_name]   || ''
    @card.author_url    = embed[:author_url].present? ? (url + embed[:author_url]).to_s : ''
    @card.provider_name = embed[:provider_name] || ''
    @card.provider_url  = embed[:provider_url].present? ? (url + embed[:provider_url]).to_s : ''
    @card.width         = 0
    @card.height        = 0

    case @card.type
    when 'link'
      @card.image_remote_url = (url + embed[:thumbnail_url]).to_s if embed[:thumbnail_url].present?
    when 'photo'
      return false if embed[:url].blank?

      @card.embed_url        = (url + embed[:url]).to_s
      @card.image_remote_url = (url + embed[:url]).to_s
      @card.width            = embed[:width].presence  || 0
      @card.height           = embed[:height].presence || 0
    when 'video'
      @card.width            = embed[:width].presence  || 0
      @card.height           = embed[:height].presence || 0
      @card.html             = Formatter.instance.sanitize(embed[:html], Sanitize::Config::MASTODON_OEMBED)
      @card.image_remote_url = (url + embed[:thumbnail_url]).to_s if embed[:thumbnail_url].present?
    when 'rich'
      # Most providers rely on <script> tags, which is a no-no
      return false
    end

    @card.save_with_optional_image!
  end

  def attempt_opengraph
    return if html.nil?

    detector = CharlockHolmes::EncodingDetector.new
    detector.strip_tags = true

    guess      = detector.detect(@html, @html_charset)
    encoding   = guess&.fetch(:confidence, 0).to_i > 60 ? guess&.fetch(:encoding, nil) : nil
    page       = Nokogiri::HTML(@html, nil, encoding)
    player_url = meta_property(page, 'twitter:player')

    if player_url && !bad_url?(Addressable::URI.parse(player_url))
      @card.type   = :video
      @card.width  = meta_property(page, 'twitter:player:width') || 0
      @card.height = meta_property(page, 'twitter:player:height') || 0
      @card.html   = content_tag(:iframe, nil, src: player_url,
                                               width: @card.width,
                                               height: @card.height,
                                               allowtransparency: 'true',
                                               scrolling: 'no',
                                               frameborder: '0')
    else
      @card.type = :link
    end

    @card.title            = meta_property(page, 'og:title').presence || page.at_xpath('//title')&.content || ''
    @card.description      = meta_property(page, 'og:description').presence || meta_property(page, 'description') || ''
    @card.image_remote_url = (Addressable::URI.parse(@url) + meta_property(page, 'og:image')).to_s if meta_property(page, 'og:image')

    return if @card.title.blank? && @card.html.blank?

    @card.save_with_optional_image!
  end

  def meta_property(page, property)
    page.at_xpath("//meta[contains(concat(' ', normalize-space(@property), ' '), ' #{property} ')]")&.attribute('content')&.value || page.at_xpath("//meta[@name=\"#{property}\"]")&.attribute('content')&.value
  end

  def lock_options
    { redis: Redis.current, key: "fetch:#{@url}", autorelease: 15.minutes.seconds }
  end
end
