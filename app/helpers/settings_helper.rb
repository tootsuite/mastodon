# frozen_string_literal: true

module SettingsHelper
  HUMAN_LOCALES = {
    af: 'Afrikaans',
    ar: 'العربية',
    ast: 'Asturianu',
    bg: 'Български',
    bn: 'বাংলা',
    br: 'Breton',
    ca: 'Català',
    co: 'Corsu',
    cs: 'Čeština',
    cy: 'Cymraeg',
    da: 'Dansk',
    de: 'Deutsch',
    el: 'Ελληνικά',
    en: 'English',
    eo: 'Esperanto',
    'es-AR': 'Español (Argentina)',
    'es-MX': 'Español (México)',
    es: 'Español',
    et: 'Eesti',
    eu: 'Euskara',
    fa: 'فارسی',
    fi: 'Suomi',
    fr: 'Français',
    ga: 'Gaeilge',
    gd: 'Gàidhlig',
    gl: 'Galego',
    he: 'עברית',
    hi: 'हिन्दी',
    hr: 'Hrvatski',
    hu: 'Magyar',
    hy: 'Հայերեն',
    id: 'Bahasa Indonesia',
    io: 'Ido',
    is: 'Íslenska',
    it: 'Italiano',
    ja: '日本語',
    ka: 'ქართული',
    kab: 'Taqbaylit',
    kk: 'Қазақша',
    kn: 'ಕನ್ನಡ',
    ko: '한국어',
    ku: 'سۆرانی',
    lt: 'Lietuvių',
    lv: 'Latviešu',
    mk: 'Македонски',
    ml: 'മലയാളം',
    mr: 'मराठी',
    ms: 'Bahasa Melayu',
    nl: 'Nederlands',
    nn: 'Nynorsk',
    no: 'Norsk',
    oc: 'Occitan',
    pl: 'Polski',
    'pt-BR': 'Português (Brasil)',
    'pt-PT': 'Português (Portugal)',
    pt: 'Português',
    ro: 'Română',
    ru: 'Русский',
    sa: 'संस्कृतम्',
    sc: 'Sardu',
    sgs: 'Žemaitėškā',
    si: 'සිංහල',
    sk: 'Slovenčina',
    sl: 'Slovenščina',
    sq: 'Shqip',
    'sr-Latn': 'Srpski (latinica)',
    sr: 'Српски',
    sv: 'Svenska',
    ta: 'தமிழ்',
    te: 'తెలుగు',
    th: 'ไทย',
    tr: 'Türkçe',
    uk: 'Українська',
    ur: 'اُردُو',
    vi: 'Tiếng Việt',
    zgh: 'ⵜⴰⵎⴰⵣⵉⵖⵜ',
    'zh-CN': '简体中文',
    'zh-HK': '繁體中文（香港）',
    'zh-TW': '繁體中文（臺灣）',
    zh: '中文',
  }.freeze

  def human_locale(locale)
    HUMAN_LOCALES[locale]
  end

  def filterable_languages
    LanguageDetector.instance.language_names.select(&HUMAN_LOCALES.method(:key?))
  end

  def hash_to_object(hash)
    HashObject.new(hash)
  end

  def session_device_icon(session)
    device = session.detection.device

    if device.mobile?
      'mobile'
    elsif device.tablet?
      'tablet'
    else
      'desktop'
    end
  end

  def compact_account_link_to(account)
    return if account.nil?

    link_to ActivityPub::TagManager.instance.url_for(account), class: 'name-tag', title: account.acct do
      safe_join([image_tag(account.avatar.url, width: 15, height: 15, alt: display_name(account), class: 'avatar'), content_tag(:span, account.acct, class: 'username')], ' ')
    end
  end

  def picture_hint(hint, picture)
    if picture.original_filename.nil?
      hint
    else
      link = link_to t('generic.delete'), settings_profile_picture_path(picture.name.to_s), data: { method: :delete }
      safe_join([hint, link], '<br/>'.html_safe)
    end
  end
end
