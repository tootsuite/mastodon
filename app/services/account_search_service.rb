# frozen_string_literal: true

class AccountSearchService < BaseService
  attr_reader :query, :limit, :offset, :options, :account

  def call(query, account = nil, options = {})
    @acct_hint = query&.start_with?('@')
    @query     = query&.strip&.gsub(/\A@/, '')
    @limit     = options[:limit].to_i
    @offset    = options[:offset].to_i
    @options   = options
    @account   = account

    search_service_results.compact.uniq
  end

  private

  def search_service_results
    return [] if query.blank? || limit < 1

    [exact_match] + search_results
  end

  def exact_match
    return unless offset.zero? && username_complete?

    return @exact_match if defined?(@exact_match)

    match = begin
      if options[:resolve]
        ResolveAccountService.new.call(query)
      elsif domain_is_local?
        Account.find_local(query_username)
      else
        Account.find_remote(query_username, query_domain)
      end
    end

    match = nil if !match.nil? && !account.nil? && options[:following] && !account.following?(match)

    @exact_match = match
  end

  def search_results
    return [] if limit_for_non_exact_results.zero?

    @search_results ||= begin
      results = from_elasticsearch if Chewy.enabled?
      results ||= from_database
      results
    end
  end

  def from_database
    AccountSearchQueryBuilder.new(
      terms_for_query,
      account: account,
      only_following: options[:following],
      limit: limit_for_non_exact_results,
      offset: offset
    ).results
  end

  def from_elasticsearch
    must_clauses   = [{ multi_match: { query: terms_for_query, fields: likely_acct? ? %w(acct.edge_ngram acct) : %w(acct.edge_ngram acct display_name.edge_ngram display_name), type: 'most_fields', operator: 'and' } }]
    should_clauses = []

    if account
      return [] if options[:following] && following_ids.empty?

      if options[:following]
        must_clauses << { terms: { id: following_ids } }
      elsif following_ids.any?
        should_clauses << { terms: { id: following_ids, boost: 100 } }
      end
    end

    query     = { bool: { must: must_clauses, should: should_clauses } }
    functions = [reputation_score_function, followers_score_function, time_distance_function]

    records = AccountsIndex.query(function_score: { query: query, functions: functions, boost_mode: 'multiply', score_mode: 'avg' })
                           .limit(limit_for_non_exact_results)
                           .offset(offset)
                           .objects
                           .compact

    ActiveRecord::Associations::Preloader.new.preload(records, :account_stat)

    records
  rescue Faraday::ConnectionFailed, Parslet::ParseFailed
    nil
  end

  def reputation_score_function
    {
      script_score: {
        script: {
          source: "(doc['followers_count'].value + 0.0) / (doc['followers_count'].value + doc['following_count'].value + 1)",
        },
      },
    }
  end

  def followers_score_function
    {
      field_value_factor: {
        field: 'followers_count',
        modifier: 'log2p',
        missing: 0,
      },
    }
  end

  def time_distance_function
    {
      gauss: {
        last_status_at: {
          scale: '30d',
          offset: '30d',
          decay: 0.3,
        },
      },
    }
  end

  def following_ids
    @following_ids ||= account.active_relationships.pluck(:target_account_id) + [account.id]
  end

  def limit_for_non_exact_results
    if exact_match?
      limit - 1
    else
      limit
    end
  end

  def terms_for_query
    if domain_is_local?
      query_username
    else
      query
    end
  end

  def split_query_string
    @split_query_string ||= query.split('@')
  end

  def query_username
    @query_username ||= split_query_string.first || ''
  end

  def query_domain
    @query_domain ||= query_without_split? ? nil : split_query_string.last
  end

  def query_without_split?
    split_query_string.size == 1
  end

  def domain_is_local?
    @domain_is_local ||= TagManager.instance.local_domain?(query_domain)
  end

  def exact_match?
    exact_match.present?
  end

  def username_complete?
    query.include?('@') && "@#{query}".match?(/\A#{Account::MENTION_RE}\Z/)
  end

  def likely_acct?
    @acct_hint || username_complete?
  end
end
