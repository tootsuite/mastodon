# frozen_string_literal: true

class FetchRemoteStatusService < BaseService
  def call(url, prefetched_body = nil)
    if prefetched_body.nil?
      atom_url, body = FetchAtomService.new.call(url)
    else
      atom_url = url
      body     = prefetched_body
    end

    return nil if atom_url.nil?
    process_atom(atom_url, body)
  end

  private

  def process_atom(url, body)
    Rails.logger.debug "Processing Atom for remote status at #{url}"

    xml = Nokogiri::XML(body)
    xml.encoding = 'utf-8'

    account = extract_author(url, xml)

    return nil if account.nil?

    statuses = ProcessFeedService.new.call(body, account)

    statuses.first
  end

  def extract_author(url, xml)
    url_parts = Addressable::URI.parse(url).normalize
    username  = xml.at_xpath('//xmlns:author/xmlns:name').try(:content)
    domain    = url_parts.host

    return nil if username.nil?

    Rails.logger.debug "Going to webfinger #{username}@#{domain}"

    return FollowRemoteAccountService.new.call("#{username}@#{domain}")
  rescue Nokogiri::XML::XPath::SyntaxError
    Rails.logger.debug 'Invalid XML or missing namespace'
    nil
  end
end
