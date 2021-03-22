# frozen_string_literal: true

require 'rails_helper'

describe AccountSearchQueryBuilder do
  before do
    Fabricate(
      :account,
      display_name: "Missing",
      username: "missing",
      domain: "missing.com"
    )
  end

  context 'without account' do
    it 'accepts ?, \, : and space as delimiter' do
      needle = Fabricate(
        :account,
        display_name: 'A & l & i & c & e',
        username: 'username',
        domain: 'example.com'
      )

      results = described_class.new('A?l\i:c e').build.to_a
      expect(results).to eq [needle]
    end

    it 'finds accounts with matching display_name' do
      needle = Fabricate(
        :account,
        display_name: "Display Name",
        username: "username",
        domain: "example.com"
      )

      results = described_class.new("display").build.to_a
      expect(results).to eq [needle]
    end

    it 'finds accounts with matching username' do
      needle = Fabricate(
        :account,
        display_name: "Display Name",
        username: "username",
        domain: "example.com"
      )

      results = described_class.new("username").build.to_a
      expect(results).to eq [needle]
    end

    it 'finds accounts with matching domain' do
      needle = Fabricate(
        :account,
        display_name: "Display Name",
        username: "username",
        domain: "example.com"
      )

      results = described_class.new("example").build.to_a
      expect(results).to eq [needle]
    end

    it 'limits by 10 by default' do
      11.times.each { Fabricate(:account, display_name: "Display Name") }
      results = described_class.new("display").build.to_a
      expect(results.size).to eq 10
    end

    it 'accepts arbitrary limits' do
      2.times.each { Fabricate(:account, display_name: "Display Name") }
      results = described_class.new("display", limit: 1).build.to_a
      expect(results.size).to eq 1
    end

    it 'ranks multiple matches higher' do
      needles = [
        { username: "username", display_name: "username" },
        { display_name: "Display Name", username: "username", domain: "example.com" },
      ].map(&method(:Fabricate).curry(2).call(:account))

      results = described_class.new("username").build.to_a
      expect(results).to eq needles
    end
  end

  context 'with account' do
    let(:account) { Fabricate(:account) }

    it 'ranks followed accounts higher' do
      needle = Fabricate(:account, username: "Matching")
      followed_needle = Fabricate(:account, username: "Matcher")
      account.follow!(followed_needle)

      results = described_class.new("match", account: account).build.to_a

      expect(results).to eq [followed_needle, needle]
      expect(results.first.rank).to be > results.last.rank
    end
  end
end
