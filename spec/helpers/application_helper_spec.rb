require 'rails_helper'

describe ApplicationHelper do
  describe 'active_nav_class' do
    it 'returns active when on the current page' do
      allow(helper).to receive(:current_page?).and_return(true)

      result = helper.active_nav_class("/test")
      expect(result).to eq "active"
    end

    it 'returns empty string when not on current page' do
      allow(helper).to receive(:current_page?).and_return(false)

      result = helper.active_nav_class("/test")
      expect(result).to eq ""
    end
  end

  describe 'add_rtl_body_class' do
    around do |example|
      current_locale = I18n.locale
      example.run
      I18n.locale = current_locale
    end

    it 'adds rtl body class if locale is Arabic' do
      I18n.locale = :ar
      expect(helper.add_rtl_body_class('other classes')).to eq 'other classes rtl'
    end

    it 'adds rtl body class if locale is Farsi' do
      I18n.locale = :fa
      expect(helper.add_rtl_body_class('other classes')).to eq 'other classes rtl'
    end

    it 'adds rtl if locale is Hebrew' do
      I18n.locale = :he
      expect(helper.add_rtl_body_class('other classes')).to eq 'other classes rtl'
    end

    it 'does not add rtl if locale is Thai' do
      I18n.locale = :th
      expect(helper.add_rtl_body_class('other classes')).to eq 'other classes'
    end
  end

  describe 'fa_icon' do
    it 'returns a tag of fixed-width cog' do
      expect(helper.fa_icon('cog fw')).to eq '<i class="fa fa-cog fa-fw"></i>'
    end
  end

  describe 'favicon_path' do
    it 'returns /favicon.ico on production enviromnent' do
      expect(Rails.env).to receive(:production?).and_return(true)
      expect(helper.favicon_path).to eq '/favicon.ico'
    end
  end

  describe 'open_registrations?' do
    it 'returns true when open for registrations' do
      without_partial_double_verification do
        expect(Setting).to receive(:open_registrations).and_return(true)
      end

      expect(helper.open_registrations?).to eq true
    end

    it 'returns false when closed for registrations' do
      without_partial_double_verification do
        expect(Setting).to receive(:open_registrations).and_return(false)
      end

      expect(helper.open_registrations?).to eq false
    end
  end

  describe 'require_approval?' do
    it 'returns true when approval is needed' do
      without_partial_double_verification do
        expect(Setting).to receive(:require_approval).and_return(true)
      end

      expect(helper.require_approval?).to eq true
    end

    it 'returns false when approval is not needed' do
      without_partial_double_verification do
        expect(Setting).to receive(:require_approval).and_return(false)
      end

      expect(helper.require_approval?).to eq false
    end
  end

  describe 'show_landing_strip?', without_verify_partial_doubles: true do
    describe 'when signed in' do
      before do
        allow(helper).to receive(:user_signed_in?).and_return(true)
      end
      it 'does not show landing strip' do
        expect(helper.show_landing_strip?).to eq false
      end
    end

    describe 'when signed out' do
      before do
        allow(helper).to receive(:user_signed_in?).and_return(false)
      end

      it 'does not show landing strip on single user instance' do
        allow(helper).to receive(:single_user_mode?).and_return(true)

        expect(helper.show_landing_strip?).to eq false
      end

      it 'shows landing strip on multi user instance' do
        allow(helper).to receive(:single_user_mode?).and_return(false)

        expect(helper.show_landing_strip?).to eq true
      end
    end
  end

  describe 'title' do
    around do |example|
      site_title = Setting.site_title
      example.run
      Setting.site_title = site_title
    end

    it 'returns site title on production enviroment' do
      Setting.site_title = 'site title'
      expect(Rails.env).to receive(:production?).and_return(true)
      expect(helper.title).to eq 'site title'
    end
  end
end
