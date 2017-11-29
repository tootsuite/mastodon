require 'rails_helper'

RSpec.describe Formatter do
  let(:local_account)  { Fabricate(:account, domain: nil, username: 'alice') }
  let(:remote_account) { Fabricate(:account, domain: 'remote', username: 'bob', url: 'https://remote/') }

  shared_examples 'encode and link URLs' do
    context 'matches a stand-alone medium URL' do
      let(:text) { 'https://hackernoon.com/the-power-to-build-communities-a-response-to-mark-zuckerberg-3f2cac9148a4' }

      it 'has valid URL' do
        is_expected.to include 'href="https://hackernoon.com/the-power-to-build-communities-a-response-to-mark-zuckerberg-3f2cac9148a4"'
      end
    end

    context 'matches a stand-alone google URL' do
      let(:text) { 'http://google.com' }

      it 'has valid URL' do
        is_expected.to include 'href="http://google.com/"'
      end
    end

    context 'matches a stand-alone IDN URL' do
      let(:text) { 'https://nic.みんな/' }

      it 'has valid URL' do
        is_expected.to include 'href="https://nic.xn--q9jyb4c/"'
      end

      it 'has display URL' do
        is_expected.to include '<span class="">nic.みんな/</span>'
      end
    end

    context 'matches a URL without trailing period' do
      let(:text) { 'http://www.mcmansionhell.com/post/156408871451/50-states-of-mcmansion-hell-scottsdale-arizona. ' }

      it 'has valid URL' do
        is_expected.to include 'href="http://www.mcmansionhell.com/post/156408871451/50-states-of-mcmansion-hell-scottsdale-arizona"'
      end
    end

    context 'matches a URL without closing paranthesis' do
      let(:text) { '(http://google.com/)' }

      it 'has valid URL' do
        is_expected.to include 'href="http://google.com/"'
      end
    end

    context 'matches a URL without exclamation point' do
      let(:text) { 'http://www.google.com!' }

      it 'has valid URL' do
        is_expected.to include 'href="http://www.google.com/"'
      end
    end

    context 'matches a URL without single quote' do
      let(:text) { "http://www.google.com'" }

      it 'has valid URL' do
        is_expected.to include 'href="http://www.google.com/"'
      end
    end

    context 'matches a URL without angle brackets' do
      let(:text) { 'http://www.google.com>' }

      it 'has valid URL' do
        is_expected.to include 'href="http://www.google.com/"'
      end
    end

    context 'matches a URL with a query string' do
      let(:text) { 'https://www.ruby-toolbox.com/search?utf8=%E2%9C%93&q=autolink' }

      it 'has valid URL' do
        is_expected.to include 'href="https://www.ruby-toolbox.com/search?utf8=%E2%9C%93&amp;q=autolink"'
      end
    end

    context 'matches a URL with parenthesis in it' do
      let(:text) { 'https://en.wikipedia.org/wiki/Diaspora_(software)' }

      it 'has valid URL' do
        is_expected.to include 'href="https://en.wikipedia.org/wiki/Diaspora_(software)"'
      end
    end

    context 'matches a URL with Japanese path string' do
      let(:text) { 'https://ja.wikipedia.org/wiki/日本' }

      it 'has valid URL' do
        is_expected.to include 'href="https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC"'
      end
    end

    context 'matches a URL with Korean path string' do
      let(:text) { 'https://ko.wikipedia.org/wiki/대한민국' }

      it 'has valid URL' do
        is_expected.to include 'href="https://ko.wikipedia.org/wiki/%EB%8C%80%ED%95%9C%EB%AF%BC%EA%B5%AD"'
      end
    end

    context 'matches a URL with Simplified Chinese path string' do
      let(:text) { 'https://baike.baidu.com/item/中华人民共和国' }

      it 'has valid URL' do
        is_expected.to include 'href="https://baike.baidu.com/item/%E4%B8%AD%E5%8D%8E%E4%BA%BA%E6%B0%91%E5%85%B1%E5%92%8C%E5%9B%BD"'
      end
    end

    context 'matches a URL with Traditional Chinese path string' do
      let(:text) { 'https://zh.wikipedia.org/wiki/臺灣' }

      it 'has valid URL' do
        is_expected.to include 'href="https://zh.wikipedia.org/wiki/%E8%87%BA%E7%81%A3"'
      end
    end

    context 'contains unsafe URL (XSS attack, visible part)' do
      let(:text) { %q{http://example.com/b<del>b</del>} }

      it 'has escaped HTML' do
        is_expected.to include '&lt;del&gt;b&lt;/del&gt;'
      end
    end

    context 'contains unsafe URL (XSS attack, invisible part)' do
      let(:text) { %q{http://example.com/blahblahblahblah/a<script>alert("Hello")</script>} }

      it 'has escaped HTML' do
        is_expected.to include '&lt;script&gt;alert(&quot;Hello&quot;)&lt;/script&gt;'
      end
    end

    context 'contains HTML (script tag)' do
      let(:text) { '<script>alert("Hello")</script>' }

      it 'has escaped HTML' do
        is_expected.to include '<p>&lt;script&gt;alert(&quot;Hello&quot;)&lt;/script&gt;</p>'
      end
    end

    context 'contains HTML (XSS attack)' do
      let(:text) { %q{<img src="javascript:alert('XSS');">} }

      it 'has escaped HTML' do
        is_expected.to include '<p>&lt;img src=&quot;javascript:alert(&apos;XSS&apos;);&quot;&gt;</p>'
      end
    end

    context 'contains invalid URL' do
      let(:text) { 'http://www\.google\.com' }

      it 'has raw URL' do
        is_expected.to eq '<p>http://www\.google\.com</p>'
      end
    end

    context 'contains a hashtag' do
      let(:text)  { '#hashtag' }

      it 'has a link' do
        is_expected.to include '/tags/hashtag" class="mention hashtag" rel="tag">#<span>hashtag</span></a>'
      end
    end
  end

  describe '#format' do
    subject { Formatter.instance.format(status) }

    context 'with local status' do
      context 'with reblog' do
        let(:reblog) { Fabricate(:status, account: local_account, text: 'Hello world', uri: nil) }
        let(:status) { Fabricate(:status, reblog: reblog) }

        it 'returns original status with credit to its author' do
          expect(subject[0]).to include 'RT <span class="h-card"><a href="https://cb6e6126.ngrok.io/@alice" class="u-url mention">@<span>alice</span></a></span> Hello world'
        end
      end

      context 'contains plain text' do
        let(:status)  { Fabricate(:status, text: 'text', uri: nil) }

        it 'paragraphizes' do
          expect(subject[0]).to eq '<p>text</p>'
        end
      end

      context 'contains line feeds' do
        let(:status)  { Fabricate(:status, text: "line\nfeed", uri: nil) }

        it 'removes line feeds' do
          expect(subject[0]).not_to include "\n"
        end
      end

      context 'contains linkable mentions' do
        let(:status) { Fabricate(:status, mentions: [ Fabricate(:mention, account: local_account) ], text: '@alice') }

        it 'links' do
          expect(subject[0]).to include '<a href="https://cb6e6126.ngrok.io/@alice" class="u-url mention">@<span>alice</span></a></span>'
        end
      end

      context 'contains unlinkable mentions' do
        let(:status) { Fabricate(:status, text: '@alice', uri: nil) }

        it 'does not link' do
          expect(subject[0]).to include '@alice'
        end
      end

      context do
        subject do
          status = Fabricate(:status, text: text, uri: nil)
          Formatter.instance.format(status)[0]
        end

        include_examples 'encode and link URLs'
      end

      context 'with emoji' do
        let!(:emoji) { Fabricate(:custom_emoji, shortcode: 'coolcat') }
        let(:status) { Fabricate(:status, account: local_account, text: ':coolcat:') }

        it 'extracts shortcode' do
          expect(Formatter.instance.format(status)[1]).to eq ['coolcat']
        end

        it 'converts shortcode to image tag when custom_emojify keyword is true' do
          expect(Formatter.instance.format(status, custom_emojify: true)[0]).to start_with '<p><img draggable="false" class="emojione" alt=":coolcat:" title=":coolcat:" src="https://cb6e6126.ngrok.io/system/custom_emojis/images/'
        end

        it 'does not convert shortcode to image tag when custom_emojify keyword is false' do
          expect(Formatter.instance.format(status, custom_emojify: false)[0]).to eq '<p>:coolcat:</p>'
        end
      end
    end

    context 'with remote status' do
      let(:status) { Fabricate(:status, account: remote_account, text: 'Beep boop') }

      it 'reformats' do
        expect(subject[0]).to eq 'Beep boop'
      end

      context 'with emoji' do
        let!(:emoji) { Fabricate(:custom_emoji, domain: remote_account.domain, shortcode: 'coolcat') }
        let(:status) { Fabricate(:status, account: remote_account, text: ':coolcat:') }

        it 'extracts shortcode' do
          expect(Formatter.instance.format(status)[1]).to eq ['coolcat']
        end

        it 'converts shortcode to image tag when custom_emojify keyword is true' do
          expect(Formatter.instance.format(status, custom_emojify: true)[0]).to start_with '<img draggable="false" class="emojione" alt=":coolcat:" title=":coolcat:" src="https://cb6e6126.ngrok.io/system/custom_emojis/images/'
        end

        it 'does not convert shortcode to image tag when custom_emojify keyword is false' do
          expect(Formatter.instance.format(status, custom_emojify: false)[0]).to eq ':coolcat:'
        end
      end
    end
  end

  describe '#reformat' do
    context 'contains plain text' do
      let(:text) { 'Beep boop' }

      it 'contains plain text' do
        expect(Formatter.instance.reformat(text, nil)[0]).to include 'Beep boop'
      end
    end

    context 'contains scripts' do
      let(:text) { '<script>alert("Hello")</script>' }

      it 'strips scripts' do
        expect(Formatter.instance.reformat(text, nil)[0]).to_not include '<script>alert("Hello")</script>'
      end
    end

    context 'contains shortcodes' do
      let(:text) { ':coolcat:' }
      let!(:custom_emoji) { Fabricate(:custom_emoji, shortcode: 'coolcat') }

      it 'does not emojify when custom_emojify keyword parameter is false' do
        expect(Formatter.instance.reformat(text, nil, custom_emojify: false)[0]).to eq ':coolcat:'
      end

      it 'emojifies when custom_emojify keyword parameter is true' do
        expect(Formatter.instance.reformat(text, nil, custom_emojify: true)[0]).to start_with '<img draggable="false" class="emojione" alt=":coolcat:" title=":coolcat:" src="https://cb6e6126.ngrok.io/system/custom_emojis/images/'
      end

      it 'returns an array including shortcodes' do
        expect(Formatter.instance.reformat(text, nil)[1]).to eq ['coolcat']
      end
    end

    context 'contains malicious classes' do
      let(:text) { '<span class="status__content__spoiler-link">Show more</span>' }

      it 'strips malicious classes' do
        expect(Formatter.instance.reformat(text, nil)[0]).to_not include 'status__content__spoiler-link'
      end
    end
  end

  describe '#plaintext' do
    subject { Formatter.instance.plaintext(status) }

    context 'with local status' do
      let(:status)  { Fabricate(:status, text: '<p>a text by a nerd who uses an HTML tag in text</p>', uri: nil) }

      it 'returns raw text' do
        is_expected.to eq '<p>a text by a nerd who uses an HTML tag in text</p>'
      end
    end

    context 'with remote status' do
      let(:status)  { Fabricate(:status, account: remote_account, text: '<script>alert("Hello")</script>') }

      it 'returns tag-stripped text' do
        is_expected.to eq ''
      end
    end
  end

  describe '#simplified_format' do
    subject { Formatter.instance.simplified_format(account) }

    context 'with local status' do
      let(:account) { Fabricate(:account, domain: nil, note: text) }

      context 'contains linkable mentions for local accounts' do
        let(:text) { '@alice' }

        before { local_account }

        it 'links' do
          is_expected.to eq '<p><span class="h-card"><a href="https://cb6e6126.ngrok.io/@alice" class="u-url mention">@<span>alice</span></a></span></p>'
        end
      end

      context 'contains linkable mentions for remote accounts' do
        let(:text) { '@bob@remote' }

        before { remote_account }

        it 'links' do
          is_expected.to eq '<p><span class="h-card"><a href="https://remote/" class="u-url mention">@<span>bob</span></a></span></p>'
        end
      end

      context 'contains unlinkable mentions' do
        let(:text) { '@alice' }

        it 'returns raw mention texts' do
          is_expected.to eq '<p>@alice</p>'
        end
      end

      include_examples 'encode and link URLs'
    end

    context 'with remote status' do
      let(:text) { '<script>alert("Hello")</script>' }
      let(:account) { Fabricate(:account, domain: 'remote', note: text) }

      it 'reformats' do
        is_expected.to_not include '<script>alert("Hello")</script>'
      end
    end
  end

  describe '#sanitize' do
    let(:html) { '<script>alert("Hello")</script>' }

    subject { Formatter.instance.sanitize(html, Sanitize::Config::MASTODON_STRICT) }

    it 'sanitizes' do
      is_expected.to eq 'alert("Hello")'
    end
  end

  describe '#format_spoiler' do
    it 'encodes with HTML entities' do
      status = Fabricate(:status, spoiler_text: "'\"<>&")
      formatted = Formatter.instance.format_spoiler(status)
      expect(formatted).to eq '&apos;&quot;&lt;&gt;&amp;'
    end

    it 'emojifies' do
      Fabricate(:custom_emoji, domain: nil, shortcode: 'coolcat')
      account = Fabricate(:account, domain: nil)
      status = Fabricate(:status, account: account, spoiler_text: ':coolcat:')

      formatted = Formatter.instance.format_spoiler(status)

      expect(formatted).to start_with '<img draggable="false" class="emojione" alt=":coolcat:" title=":coolcat:" src="https://cb6e6126.ngrok.io/system/custom_emojis/images/'
    end
  end
end
