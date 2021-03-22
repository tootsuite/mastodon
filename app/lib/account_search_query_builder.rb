# frozen_string_literal: true

class AccountSearchQueryBuilder
  DISALLOWED_TSQUERY_CHARACTERS = /['?\\:‘’]/.freeze

  LANGUAGE     = Arel::Nodes.build_quoted('simple').freeze
  EMPTY_STRING = Arel::Nodes.build_quoted('').freeze
  WEIGHT_A     = Arel::Nodes.build_quoted('A').freeze
  WEIGHT_B     = Arel::Nodes.build_quoted('B').freeze
  WEIGHT_C     = Arel::Nodes.build_quoted('C').freeze

  FIELDS = {
    display_name: { weight: WEIGHT_A }.freeze,
    username:     { weight: WEIGHT_B }.freeze,
    domain:       { weight: WEIGHT_C, nullable: true }.freeze,
  }.freeze

  RANK_NORMALIZATION = 32

  DEFAULT_OPTIONS = {
    limit: 10,
    only_following: false,
  }.freeze

  # @param [String] terms
  # @param [Hash] options
  # @option [Account] :account
  # @option [Boolean] :only_following
  # @option [Integer] :limit
  # @option [Integer] :offset
  def initialize(terms, options = {})
    @terms   = terms
    @options = DEFAULT_OPTIONS.merge(options)
  end

  # @return [ActiveRecord::Relation]
  def build
    search_scope.tap do |scope|
      scope.merge!(personalization_scope) if with_account?

      if with_account? && only_following?
        scope.merge!(only_following_scope)
        scope.with!(first_degree_definition) # `merge!` does not handle `with`
      end
    end
  end

  # @return [Array<Account>]
  def results
    build.to_a
  end

  private

  def search_scope
    Account.select(projections)
           .where(match_condition)
           .searchable
           .includes(:account_stat)
           .order(rank: :desc)
           .limit(limit)
           .offset(offset)
  end

  def personalization_scope
    join_condition = accounts_table.join(follows_table, Arel::Nodes::OuterJoin)
                                   .on(accounts_table.grouping(accounts_table[:id].eq(follows_table[:account_id]).and(follows_table[:target_account_id].eq(account.id))).or(accounts_table.grouping(accounts_table[:id].eq(follows_table[:target_account_id]).and(follows_table[:account_id].eq(account.id)))))
                                   .join_sources

    Account.joins(join_condition)
           .group(accounts_table[:id])
  end

  def only_following_scope
    Account.where(accounts_table[:id].in(first_degree_table.project('*')))
  end

  def first_degree_definition
    target_account_ids_query = follows_table.project(follows_table[:target_account_id]).where(follows_table[:account_id].eq(account.id))
    account_id_query         = Arel::SelectManager.new.project(account.id)

    Arel::Nodes::As.new(
      first_degree_table,
      target_account_ids_query.union(:all, account_id_query)
    )
  end

  def projections
    rank_column = begin
      if with_account?
        weighted_tsrank_template.as('rank')
      else
        tsrank_template.as('rank')
      end
    end

    [all_columns, rank_column]
  end

  def all_columns
    accounts_table[Arel.star]
  end

  def match_condition
    Arel::Nodes::InfixOperation.new('@@', tsvector_template, tsquery_template)
  end

  def tsrank_template
    @tsrank_template ||= Arel::Nodes::NamedFunction.new('ts_rank_cd', [tsvector_template, tsquery_template, RANK_NORMALIZATION])
  end

  def weighted_tsrank_template
    @weighted_tsrank_template ||= Arel::Nodes::Multiplication.new(weight, tsrank_template)
  end

  def weight
    Arel::Nodes::Addition.new(follows_table[:id].count, 1)
  end

  def tsvector_template
    return @tsvector_template if defined?(@tsvector_template)

    vectors = FIELDS.keys.map do |column|
      options = FIELDS[column]

      vector = accounts_table[column]
      vector = Arel::Nodes::NamedFunction.new('coalesce', [vector, EMPTY_STRING]) if options[:nullable]
      vector = Arel::Nodes::NamedFunction.new('to_tsvector', [LANGUAGE, vector])

      Arel::Nodes::NamedFunction.new('setweight', [vector, options[:weight]])
    end

    @tsvector_template = Arel::Nodes::Grouping.new(vectors.reduce { |memo, vector| Arel::Nodes::Concat.new(memo, vector) })
  end

  def query_vector
    @query_vector ||= Arel::Nodes::NamedFunction.new('to_tsquery', [LANGUAGE, tsquery_template])
  end

  def sanitized_terms
    @sanitized_terms ||= @terms.gsub(DISALLOWED_TSQUERY_CHARACTERS, ' ')
  end

  def tsquery_template
    return @tsquery_template if defined?(@tsquery_template)

    terms = [
      Arel::Nodes.build_quoted("' "),
      Arel::Nodes.build_quoted(sanitized_terms),
      Arel::Nodes.build_quoted(" '"),
      Arel::Nodes.build_quoted(':*'),
    ]

    @tsquery_template = Arel::Nodes::NamedFunction.new('to_tsquery', [LANGUAGE, terms.reduce { |memo, term| Arel::Nodes::Concat.new(memo, term) }])
  end

  def account
    @options[:account]
  end

  def with_account?
    account.present?
  end

  def limit
    @options[:limit]
  end

  def offset
    @options[:offset]
  end

  def only_following?
    @options[:only_following]
  end

  def accounts_table
    Account.arel_table
  end

  def follows_table
    Follow.arel_table
  end

  def first_degree_table
    Arel::Table.new(:first_degree)
  end
end
