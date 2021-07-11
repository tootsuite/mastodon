# frozen_string_literal: true

class PermalinkRedirector
  include RoutingHelper

  def initialize(path)
    @path = path
  end

  def redirect_path
    if path_segments[0] == 'web'
      if path_segments[1].present? && path_segments[1].start_with?('@') && path_segments[2] =~ /\d/
        find_status_url_by_id(path_segments[2])
      elsif path_segments[1].present? && path_segments[1].start_with?('@')
        find_account_url_by_name(path_segments[1])
      elsif path_segments[1] == 'statuses' && path_segments[2] =~ /\d/
        find_status_url_by_id(path_segments[2])
      elsif path_segments[1] == 'accounts' && path_segments[2] =~ /\d/
        find_account_url_by_id(path_segments[2])
      elsif path_segments[1] == 'timelines' && path_segments[2] == 'tag' && path_segments[3].present?
        find_tag_url_by_name(path_segments[3])
      elsif path_segments[1] == 'tags' && path_segments[2].present?
        find_tag_url_by_name(path_segments[2])
      end
    end
  end

  private

  def path_segments
    @path_segments ||= @path.split('/')
  end

  def find_status_url_by_id(id)
    status = Status.find_by(id: id)

    return unless status&.distributable?

    ActivityPub::TagManager.instance.url_for(status)
  end

  def find_account_url_by_id(id)
    account = Account.find_by(id: id)

    return unless account

    ActivityPub::TagManager.instance.url_for(account)
  end

  def find_account_url_by_name(name)
    username, domain = name.gsub(/\A@/, '').split('@')
    domain           = nil if TagManager.instance.local_domain?(domain)
    account          = Account.find_remote(username, domain)

    return unless account

    ActivityPub::TagManager.instance.url_for(account)
  end

  def find_tag_url_by_name(name)
    tag_path(CGI.unescape(name))
  end
end
