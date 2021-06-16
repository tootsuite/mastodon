# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'StatsD'
  inflect.acronym 'OEmbed'
  inflect.acronym 'OStatus'
  inflect.acronym 'ActivityPub'
  inflect.acronym 'PubSubHubbub'
  inflect.acronym 'ActivityStreams'
  inflect.acronym 'JsonLd'
  inflect.acronym 'NodeInfo'
  inflect.acronym 'Ed25519'
  inflect.acronym 'TOC'
  inflect.acronym 'RSS'
  inflect.acronym 'REST'
  inflect.acronym 'URL'
  inflect.acronym 'IP'

  inflect.singular 'data', 'data'
end
