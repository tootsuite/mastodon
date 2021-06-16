# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_06_16_214526) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_aliases", force: :cascade do |t|
    t.bigint "account_id"
    t.string "acct", default: "", null: false
    t.string "uri", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_aliases_on_account_id"
  end

  create_table "account_conversations", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "conversation_id"
    t.bigint "participant_account_ids", default: [], null: false, array: true
    t.bigint "status_ids", default: [], null: false, array: true
    t.bigint "last_status_id"
    t.integer "lock_version", default: 0, null: false
    t.boolean "unread", default: false, null: false
    t.index ["account_id", "conversation_id", "participant_account_ids"], name: "index_unique_conversations", unique: true
    t.index ["conversation_id"], name: "index_account_conversations_on_conversation_id"
  end

  create_table "account_deletion_requests", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_deletion_requests_on_account_id"
  end

  create_table "account_domain_blocks", force: :cascade do |t|
    t.string "domain"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id"
    t.index ["account_id", "domain"], name: "index_account_domain_blocks_on_account_id_and_domain", unique: true
  end

  create_table "account_identity_proofs", force: :cascade do |t|
    t.bigint "account_id"
    t.string "provider", default: "", null: false
    t.string "provider_username", default: "", null: false
    t.text "token", default: "", null: false
    t.boolean "verified", default: false, null: false
    t.boolean "live", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider", "provider_username"], name: "index_account_proofs_on_account_and_provider_and_username", unique: true
  end

  create_table "account_migrations", force: :cascade do |t|
    t.bigint "account_id"
    t.string "acct", default: "", null: false
    t.bigint "followers_count", default: 0, null: false
    t.bigint "target_account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_migrations_on_account_id"
    t.index ["target_account_id"], name: "index_account_migrations_on_target_account_id"
  end

  create_table "account_moderation_notes", force: :cascade do |t|
    t.text "content", null: false
    t.bigint "account_id", null: false
    t.bigint "target_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_moderation_notes_on_account_id"
    t.index ["target_account_id"], name: "index_account_moderation_notes_on_target_account_id"
  end

  create_table "account_notes", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "target_account_id"
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "target_account_id"], name: "index_account_notes_on_account_id_and_target_account_id", unique: true
    t.index ["target_account_id"], name: "index_account_notes_on_target_account_id"
  end

  create_table "account_pins", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "target_account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "target_account_id"], name: "index_account_pins_on_account_id_and_target_account_id", unique: true
    t.index ["target_account_id"], name: "index_account_pins_on_target_account_id"
  end

  create_table "account_stats", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "statuses_count", default: 0, null: false
    t.bigint "following_count", default: 0, null: false
    t.bigint "followers_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_status_at"
    t.index ["account_id"], name: "index_account_stats_on_account_id", unique: true
  end

  create_table "account_warning_presets", force: :cascade do |t|
    t.text "text", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title", default: "", null: false
  end

  create_table "account_warnings", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "target_account_id"
    t.integer "action", default: 0, null: false
    t.text "text", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_warnings_on_account_id"
    t.index ["target_account_id"], name: "index_account_warnings_on_target_account_id"
  end

  create_table "accounts", id: :bigint, default: -> { "timestamp_id('accounts'::text)" }, force: :cascade do |t|
    t.string "username", default: "", null: false
    t.string "domain"
    t.text "private_key"
    t.text "public_key", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "note", default: "", null: false
    t.string "display_name", default: "", null: false
    t.string "uri", default: "", null: false
    t.string "url"
    t.string "avatar_file_name"
    t.string "avatar_content_type"
    t.integer "avatar_file_size"
    t.datetime "avatar_updated_at"
    t.string "header_file_name"
    t.string "header_content_type"
    t.integer "header_file_size"
    t.datetime "header_updated_at"
    t.string "avatar_remote_url"
    t.boolean "locked", default: false, null: false
    t.string "header_remote_url", default: "", null: false
    t.datetime "last_webfingered_at"
    t.string "inbox_url", default: "", null: false
    t.string "outbox_url", default: "", null: false
    t.string "shared_inbox_url", default: "", null: false
    t.string "followers_url", default: "", null: false
    t.integer "protocol", default: 0, null: false
    t.boolean "memorial", default: false, null: false
    t.bigint "moved_to_account_id"
    t.string "featured_collection_url"
    t.jsonb "fields"
    t.string "actor_type"
    t.boolean "discoverable"
    t.string "also_known_as", array: true
    t.datetime "silenced_at"
    t.datetime "suspended_at"
    t.integer "trust_level"
    t.boolean "hide_collections"
    t.integer "avatar_storage_schema_version"
    t.integer "header_storage_schema_version"
    t.string "devices_url"
    t.integer "suspension_origin"
    t.datetime "sensitized_at"
    t.index "(((setweight(to_tsvector('simple'::regconfig, (display_name)::text), 'A'::\"char\") || setweight(to_tsvector('simple'::regconfig, (username)::text), 'B'::\"char\")) || setweight(to_tsvector('simple'::regconfig, (COALESCE(domain, ''::character varying))::text), 'C'::\"char\")))", name: "search_index", using: :gin
    t.index "lower((username)::text), COALESCE(lower((domain)::text), ''::text)", name: "index_accounts_on_username_and_domain_lower", unique: true
    t.index ["moved_to_account_id"], name: "index_accounts_on_moved_to_account_id"
    t.index ["uri"], name: "index_accounts_on_uri"
    t.index ["url"], name: "index_accounts_on_url"
  end

  create_table "accounts_tags", id: false, force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "tag_id", null: false
    t.index ["account_id", "tag_id"], name: "index_accounts_tags_on_account_id_and_tag_id"
    t.index ["tag_id", "account_id"], name: "index_accounts_tags_on_tag_id_and_account_id", unique: true
  end

  create_table "admin_action_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.string "action", default: "", null: false
    t.string "target_type"
    t.bigint "target_id"
    t.text "recorded_changes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_admin_action_logs_on_account_id"
    t.index ["target_type", "target_id"], name: "index_admin_action_logs_on_target_type_and_target_id"
  end

  create_table "announcement_mutes", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "announcement_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "announcement_id"], name: "index_announcement_mutes_on_account_id_and_announcement_id", unique: true
    t.index ["announcement_id"], name: "index_announcement_mutes_on_announcement_id"
  end

  create_table "announcement_reactions", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "announcement_id"
    t.string "name", default: "", null: false
    t.bigint "custom_emoji_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "announcement_id", "name"], name: "index_announcement_reactions_on_account_id_and_announcement_id", unique: true
    t.index ["announcement_id"], name: "index_announcement_reactions_on_announcement_id"
    t.index ["custom_emoji_id"], name: "index_announcement_reactions_on_custom_emoji_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.text "text", default: "", null: false
    t.boolean "published", default: false, null: false
    t.boolean "all_day", default: false, null: false
    t.datetime "scheduled_at"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "published_at"
    t.bigint "status_ids", array: true
  end

  create_table "backups", force: :cascade do |t|
    t.bigint "user_id"
    t.string "dump_file_name"
    t.string "dump_content_type"
    t.datetime "dump_updated_at"
    t.boolean "processed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "dump_file_size"
  end

  create_table "blocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "target_account_id", null: false
    t.string "uri"
    t.index ["account_id", "target_account_id"], name: "index_blocks_on_account_id_and_target_account_id", unique: true
    t.index ["target_account_id"], name: "index_blocks_on_target_account_id"
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "status_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status_id"], name: "index_bookmarks_on_account_id_and_status_id", unique: true
    t.index ["status_id"], name: "index_bookmarks_on_status_id"
  end

  create_table "canonical_email_blocks", force: :cascade do |t|
    t.string "canonical_email_hash", default: "", null: false
    t.bigint "reference_account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["canonical_email_hash"], name: "index_canonical_email_blocks_on_canonical_email_hash", unique: true
    t.index ["reference_account_id"], name: "index_canonical_email_blocks_on_reference_account_id"
  end

  create_table "conversation_mutes", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "account_id", null: false
    t.index ["account_id", "conversation_id"], name: "index_conversation_mutes_on_account_id_and_conversation_id", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.string "uri"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uri"], name: "index_conversations_on_uri", unique: true
  end

  create_table "custom_emoji_categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_custom_emoji_categories_on_name", unique: true
  end

  create_table "custom_emojis", force: :cascade do |t|
    t.string "shortcode", default: "", null: false
    t.string "domain"
    t.string "image_file_name"
    t.string "image_content_type"
    t.integer "image_file_size"
    t.datetime "image_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "disabled", default: false, null: false
    t.string "uri"
    t.string "image_remote_url"
    t.boolean "visible_in_picker", default: true, null: false
    t.bigint "category_id"
    t.integer "image_storage_schema_version"
    t.index ["shortcode", "domain"], name: "index_custom_emojis_on_shortcode_and_domain", unique: true
  end

  create_table "custom_filters", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "expires_at"
    t.text "phrase", default: "", null: false
    t.string "context", default: [], null: false, array: true
    t.boolean "irreversible", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "whole_word", default: true, null: false
    t.index ["account_id"], name: "index_custom_filters_on_account_id"
  end

  create_table "devices", force: :cascade do |t|
    t.bigint "access_token_id"
    t.bigint "account_id"
    t.string "device_id", default: "", null: false
    t.string "name", default: "", null: false
    t.text "fingerprint_key", default: "", null: false
    t.text "identity_key", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_token_id"], name: "index_devices_on_access_token_id"
    t.index ["account_id"], name: "index_devices_on_account_id"
  end

  create_table "domain_allows", force: :cascade do |t|
    t.string "domain", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_domain_allows_on_domain", unique: true
  end

  create_table "domain_blocks", force: :cascade do |t|
    t.string "domain", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "severity", default: 0
    t.boolean "reject_media", default: false, null: false
    t.boolean "reject_reports", default: false, null: false
    t.text "private_comment"
    t.text "public_comment"
    t.boolean "obfuscate", default: false, null: false
    t.index ["domain"], name: "index_domain_blocks_on_domain", unique: true
  end

  create_table "email_domain_blocks", force: :cascade do |t|
    t.string "domain", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.index ["domain"], name: "index_email_domain_blocks_on_domain", unique: true
  end

  create_table "encrypted_messages", id: :bigint, default: -> { "timestamp_id('encrypted_messages'::text)" }, force: :cascade do |t|
    t.bigint "device_id"
    t.bigint "from_account_id"
    t.string "from_device_id", default: "", null: false
    t.integer "type", default: 0, null: false
    t.text "body", default: "", null: false
    t.text "digest", default: "", null: false
    t.text "message_franking", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_encrypted_messages_on_device_id"
    t.index ["from_account_id"], name: "index_encrypted_messages_on_from_account_id"
  end

  create_table "favourites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "status_id", null: false
    t.index ["account_id", "id"], name: "index_favourites_on_account_id_and_id"
    t.index ["account_id", "status_id"], name: "index_favourites_on_account_id_and_status_id", unique: true
    t.index ["status_id"], name: "index_favourites_on_status_id"
  end

  create_table "featured_tags", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "tag_id"
    t.bigint "statuses_count", default: 0, null: false
    t.datetime "last_status_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_featured_tags_on_account_id"
    t.index ["tag_id"], name: "index_featured_tags_on_tag_id"
  end

  create_table "follow_recommendation_suppressions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["account_id"], name: "index_follow_recommendation_suppressions_on_account_id", unique: true
  end

  create_table "follow_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "target_account_id", null: false
    t.boolean "show_reblogs", default: true, null: false
    t.string "uri"
    t.boolean "notify", default: false, null: false
    t.index ["account_id", "target_account_id"], name: "index_follow_requests_on_account_id_and_target_account_id", unique: true
  end

  create_table "follows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "target_account_id", null: false
    t.boolean "show_reblogs", default: true, null: false
    t.string "uri"
    t.boolean "notify", default: false, null: false
    t.index ["account_id", "target_account_id"], name: "index_follows_on_account_id_and_target_account_id", unique: true
    t.index ["target_account_id"], name: "index_follows_on_target_account_id"
  end

  create_table "identities", force: :cascade do |t|
    t.string "provider", default: "", null: false
    t.string "uid", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "imports", force: :cascade do |t|
    t.integer "type", null: false
    t.boolean "approved", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "data_file_name"
    t.string "data_content_type"
    t.integer "data_file_size"
    t.datetime "data_updated_at"
    t.bigint "account_id", null: false
    t.boolean "overwrite", default: false, null: false
  end

  create_table "invites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "code", default: "", null: false
    t.datetime "expires_at"
    t.integer "max_uses"
    t.integer "uses", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "autofollow", default: false, null: false
    t.text "comment"
    t.index ["code"], name: "index_invites_on_code", unique: true
    t.index ["user_id"], name: "index_invites_on_user_id"
  end

  create_table "ip_blocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.inet "ip", default: "0.0.0.0", null: false
    t.integer "severity", default: 0, null: false
    t.text "comment", default: "", null: false
  end

  create_table "list_accounts", force: :cascade do |t|
    t.bigint "list_id", null: false
    t.bigint "account_id", null: false
    t.bigint "follow_id"
    t.index ["account_id", "list_id"], name: "index_list_accounts_on_account_id_and_list_id", unique: true
    t.index ["follow_id"], name: "index_list_accounts_on_follow_id"
    t.index ["list_id", "account_id"], name: "index_list_accounts_on_list_id_and_account_id"
  end

  create_table "lists", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "title", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "replies_policy", default: 0, null: false
    t.index ["account_id"], name: "index_lists_on_account_id"
  end

  create_table "login_activities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "authentication_method"
    t.string "provider"
    t.boolean "success"
    t.string "failure_reason"
    t.inet "ip"
    t.string "user_agent"
    t.datetime "created_at"
    t.index ["user_id"], name: "index_login_activities_on_user_id"
  end

  create_table "markers", force: :cascade do |t|
    t.bigint "user_id"
    t.string "timeline", default: "", null: false
    t.bigint "last_read_id", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "timeline"], name: "index_markers_on_user_id_and_timeline", unique: true
  end

  create_table "media_attachments", id: :bigint, default: -> { "timestamp_id('media_attachments'::text)" }, force: :cascade do |t|
    t.bigint "status_id"
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at"
    t.string "remote_url", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "shortcode"
    t.integer "type", default: 0, null: false
    t.json "file_meta"
    t.bigint "account_id"
    t.text "description"
    t.bigint "scheduled_status_id"
    t.string "blurhash"
    t.integer "processing"
    t.integer "file_storage_schema_version"
    t.string "thumbnail_file_name"
    t.string "thumbnail_content_type"
    t.integer "thumbnail_file_size"
    t.datetime "thumbnail_updated_at"
    t.string "thumbnail_remote_url"
    t.index ["account_id", "status_id"], name: "index_media_attachments_on_account_id_and_status_id", order: { status_id: :desc }
    t.index ["scheduled_status_id"], name: "index_media_attachments_on_scheduled_status_id"
    t.index ["shortcode"], name: "index_media_attachments_on_shortcode", unique: true
    t.index ["status_id"], name: "index_media_attachments_on_status_id"
  end

  create_table "mentions", force: :cascade do |t|
    t.bigint "status_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id"
    t.boolean "silent", default: false, null: false
    t.index ["account_id", "status_id"], name: "index_mentions_on_account_id_and_status_id", unique: true
    t.index ["status_id"], name: "index_mentions_on_status_id"
  end

  create_table "mutes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "hide_notifications", default: true, null: false
    t.bigint "account_id", null: false
    t.bigint "target_account_id", null: false
    t.datetime "expires_at"
    t.index ["account_id", "target_account_id"], name: "index_mutes_on_account_id_and_target_account_id", unique: true
    t.index ["target_account_id"], name: "index_mutes_on_target_account_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.string "activity_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "from_account_id", null: false
    t.string "type"
    t.index ["account_id", "id", "type"], name: "index_notifications_on_account_id_and_id_and_type", order: { id: :desc }
    t.index ["activity_id", "activity_type"], name: "index_notifications_on_activity_id_and_activity_type"
    t.index ["from_account_id"], name: "index_notifications_on_from_account_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.bigint "application_id", null: false
    t.bigint "resource_owner_id", null: false
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.bigint "application_id"
    t.bigint "resource_owner_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "superapp", default: false, null: false
    t.string "website"
    t.string "owner_type"
    t.bigint "owner_id"
    t.boolean "confidential", default: true, null: false
    t.index ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "one_time_keys", force: :cascade do |t|
    t.bigint "device_id"
    t.string "key_id", default: "", null: false
    t.text "key", default: "", null: false
    t.text "signature", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_one_time_keys_on_device_id"
    t.index ["key_id"], name: "index_one_time_keys_on_key_id"
  end

  create_table "pghero_space_stats", force: :cascade do |t|
    t.text "database"
    t.text "schema"
    t.text "relation"
    t.bigint "size"
    t.datetime "captured_at"
    t.index ["database", "captured_at"], name: "index_pghero_space_stats_on_database_and_captured_at"
  end

  create_table "poll_votes", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "poll_id"
    t.integer "choice", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uri"
    t.index ["account_id"], name: "index_poll_votes_on_account_id"
    t.index ["poll_id"], name: "index_poll_votes_on_poll_id"
  end

  create_table "polls", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "status_id"
    t.datetime "expires_at"
    t.string "options", default: [], null: false, array: true
    t.bigint "cached_tallies", default: [], null: false, array: true
    t.boolean "multiple", default: false, null: false
    t.boolean "hide_totals", default: false, null: false
    t.bigint "votes_count", default: 0, null: false
    t.datetime "last_fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "voters_count"
    t.index ["account_id"], name: "index_polls_on_account_id"
    t.index ["status_id"], name: "index_polls_on_status_id"
  end

  create_table "preview_cards", force: :cascade do |t|
    t.string "url", default: "", null: false
    t.string "title", default: "", null: false
    t.string "description", default: "", null: false
    t.string "image_file_name"
    t.string "image_content_type"
    t.integer "image_file_size"
    t.datetime "image_updated_at"
    t.integer "type", default: 0, null: false
    t.text "html", default: "", null: false
    t.string "author_name", default: "", null: false
    t.string "author_url", default: "", null: false
    t.string "provider_name", default: "", null: false
    t.string "provider_url", default: "", null: false
    t.integer "width", default: 0, null: false
    t.integer "height", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "embed_url", default: "", null: false
    t.integer "image_storage_schema_version"
    t.string "blurhash"
    t.index ["url"], name: "index_preview_cards_on_url", unique: true
  end

  create_table "preview_cards_statuses", id: false, force: :cascade do |t|
    t.bigint "preview_card_id", null: false
    t.bigint "status_id", null: false
    t.index ["status_id", "preview_card_id"], name: "index_preview_cards_statuses_on_status_id_and_preview_card_id"
  end

  create_table "relays", force: :cascade do |t|
    t.string "inbox_url", default: "", null: false
    t.string "follow_activity_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "state", default: 0, null: false
  end

  create_table "report_notes", force: :cascade do |t|
    t.text "content", null: false
    t.bigint "report_id", null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_report_notes_on_account_id"
    t.index ["report_id"], name: "index_report_notes_on_report_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "status_ids", default: [], null: false, array: true
    t.text "comment", default: "", null: false
    t.boolean "action_taken", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "action_taken_by_account_id"
    t.bigint "target_account_id", null: false
    t.bigint "assigned_account_id"
    t.string "uri"
    t.boolean "forwarded"
    t.index ["account_id"], name: "index_reports_on_account_id"
    t.index ["target_account_id"], name: "index_reports_on_target_account_id"
  end

  create_table "rules", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.datetime "deleted_at"
    t.text "text", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scheduled_statuses", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "scheduled_at"
    t.jsonb "params"
    t.index ["account_id"], name: "index_scheduled_statuses_on_account_id"
    t.index ["scheduled_at"], name: "index_scheduled_statuses_on_scheduled_at"
  end

  create_table "session_activations", force: :cascade do |t|
    t.string "session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent", default: "", null: false
    t.inet "ip"
    t.bigint "access_token_id"
    t.bigint "user_id", null: false
    t.bigint "web_push_subscription_id"
    t.index ["access_token_id"], name: "index_session_activations_on_access_token_id"
    t.index ["session_id"], name: "index_session_activations_on_session_id", unique: true
    t.index ["user_id"], name: "index_session_activations_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "var", null: false
    t.text "value"
    t.string "thing_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.bigint "thing_id"
    t.index ["thing_type", "thing_id", "var"], name: "index_settings_on_thing_type_and_thing_id_and_var", unique: true
  end

  create_table "site_uploads", force: :cascade do |t|
    t.string "var", default: "", null: false
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at"
    t.json "meta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["var"], name: "index_site_uploads_on_var", unique: true
  end

  create_table "status_pins", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "status_id", null: false
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.datetime "updated_at", default: -> { "now()" }, null: false
    t.index ["account_id", "status_id"], name: "index_status_pins_on_account_id_and_status_id", unique: true
  end

  create_table "status_stats", force: :cascade do |t|
    t.bigint "status_id", null: false
    t.bigint "replies_count", default: 0, null: false
    t.bigint "reblogs_count", default: 0, null: false
    t.bigint "favourites_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status_id"], name: "index_status_stats_on_status_id", unique: true
  end

  create_table "statuses", id: :bigint, default: -> { "timestamp_id('statuses'::text)" }, force: :cascade do |t|
    t.string "uri"
    t.text "text", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "in_reply_to_id"
    t.bigint "reblog_of_id"
    t.string "url"
    t.boolean "sensitive", default: false, null: false
    t.integer "visibility", default: 0, null: false
    t.text "spoiler_text", default: "", null: false
    t.boolean "reply", default: false, null: false
    t.string "language"
    t.bigint "conversation_id"
    t.boolean "local"
    t.bigint "account_id", null: false
    t.bigint "application_id"
    t.bigint "in_reply_to_account_id"
    t.bigint "poll_id"
    t.datetime "deleted_at"
    t.index ["account_id", "id", "visibility", "updated_at"], name: "index_statuses_20190820", order: { id: :desc }, where: "(deleted_at IS NULL)"
    t.index ["id", "account_id"], name: "index_statuses_local_20190824", order: { id: :desc }, where: "((local OR (uri IS NULL)) AND (deleted_at IS NULL) AND (visibility = 0) AND (reblog_of_id IS NULL) AND ((NOT reply) OR (in_reply_to_account_id = account_id)))"
    t.index ["id", "account_id"], name: "index_statuses_public_20200119", order: { id: :desc }, where: "((deleted_at IS NULL) AND (visibility = 0) AND (reblog_of_id IS NULL) AND ((NOT reply) OR (in_reply_to_account_id = account_id)))"
    t.index ["in_reply_to_account_id"], name: "index_statuses_on_in_reply_to_account_id"
    t.index ["in_reply_to_id"], name: "index_statuses_on_in_reply_to_id"
    t.index ["reblog_of_id", "account_id"], name: "index_statuses_on_reblog_of_id_and_account_id"
    t.index ["uri"], name: "index_statuses_on_uri", unique: true
  end

  create_table "statuses_tags", id: false, force: :cascade do |t|
    t.bigint "status_id", null: false
    t.bigint "tag_id", null: false
    t.index ["status_id"], name: "index_statuses_tags_on_status_id"
    t.index ["tag_id", "status_id"], name: "index_statuses_tags_on_tag_id_and_status_id", unique: true
  end

  create_table "system_keys", force: :cascade do |t|
    t.binary "key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "usable"
    t.boolean "trendable"
    t.boolean "listable"
    t.datetime "reviewed_at"
    t.datetime "requested_review_at"
    t.datetime "last_status_at"
    t.float "max_score"
    t.datetime "max_score_at"
    t.index "lower((name)::text) text_pattern_ops", name: "index_tags_on_name_lower_btree", unique: true
  end

  create_table "tombstones", force: :cascade do |t|
    t.bigint "account_id"
    t.string "uri", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "by_moderator"
    t.index ["account_id"], name: "index_tombstones_on_account_id"
    t.index ["uri"], name: "index_tombstones_on_uri"
  end

  create_table "unavailable_domains", force: :cascade do |t|
    t.string "domain", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_unavailable_domains_on_domain", unique: true
  end

  create_table "user_invite_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.text "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_invite_requests_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.boolean "admin", default: false, null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "locale"
    t.string "encrypted_otp_secret"
    t.string "encrypted_otp_secret_iv"
    t.string "encrypted_otp_secret_salt"
    t.integer "consumed_timestep"
    t.boolean "otp_required_for_login", default: false, null: false
    t.datetime "last_emailed_at"
    t.string "otp_backup_codes", array: true
    t.string "filtered_languages", default: [], null: false, array: true
    t.bigint "account_id", null: false
    t.boolean "disabled", default: false, null: false
    t.boolean "moderator", default: false, null: false
    t.bigint "invite_id"
    t.string "remember_token"
    t.string "chosen_languages", array: true
    t.bigint "created_by_application_id"
    t.boolean "approved", default: true, null: false
    t.string "sign_in_token"
    t.datetime "sign_in_token_sent_at"
    t.string "webauthn_id"
    t.inet "sign_up_ip"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["created_by_application_id"], name: "index_users_on_created_by_application_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["remember_token"], name: "index_users_on_remember_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "web_push_subscriptions", force: :cascade do |t|
    t.string "endpoint", null: false
    t.string "key_p256dh", null: false
    t.string "key_auth", null: false
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "access_token_id"
    t.bigint "user_id"
    t.index ["access_token_id"], name: "index_web_push_subscriptions_on_access_token_id"
    t.index ["user_id"], name: "index_web_push_subscriptions_on_user_id"
  end

  create_table "web_settings", force: :cascade do |t|
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_web_settings_on_user_id", unique: true
  end

  create_table "webauthn_credentials", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "public_key", null: false
    t.string "nickname", null: false
    t.bigint "sign_count", default: 0, null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_webauthn_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_webauthn_credentials_on_user_id"
  end

  add_foreign_key "account_aliases", "accounts", on_delete: :cascade
  add_foreign_key "account_conversations", "accounts", on_delete: :cascade
  add_foreign_key "account_conversations", "conversations", on_delete: :cascade
  add_foreign_key "account_deletion_requests", "accounts", on_delete: :cascade
  add_foreign_key "account_domain_blocks", "accounts", name: "fk_206c6029bd", on_delete: :cascade
  add_foreign_key "account_identity_proofs", "accounts", on_delete: :cascade
  add_foreign_key "account_migrations", "accounts", column: "target_account_id", on_delete: :nullify
  add_foreign_key "account_migrations", "accounts", on_delete: :cascade
  add_foreign_key "account_moderation_notes", "accounts"
  add_foreign_key "account_moderation_notes", "accounts", column: "target_account_id"
  add_foreign_key "account_notes", "accounts", column: "target_account_id", on_delete: :cascade
  add_foreign_key "account_notes", "accounts", on_delete: :cascade
  add_foreign_key "account_pins", "accounts", column: "target_account_id", on_delete: :cascade
  add_foreign_key "account_pins", "accounts", on_delete: :cascade
  add_foreign_key "account_stats", "accounts", on_delete: :cascade
  add_foreign_key "account_warnings", "accounts", column: "target_account_id", on_delete: :cascade
  add_foreign_key "account_warnings", "accounts", on_delete: :nullify
  add_foreign_key "accounts", "accounts", column: "moved_to_account_id", on_delete: :nullify
  add_foreign_key "admin_action_logs", "accounts", on_delete: :cascade
  add_foreign_key "announcement_mutes", "accounts", on_delete: :cascade
  add_foreign_key "announcement_mutes", "announcements", on_delete: :cascade
  add_foreign_key "announcement_reactions", "accounts", on_delete: :cascade
  add_foreign_key "announcement_reactions", "announcements", on_delete: :cascade
  add_foreign_key "announcement_reactions", "custom_emojis", on_delete: :cascade
  add_foreign_key "backups", "users", on_delete: :nullify
  add_foreign_key "blocks", "accounts", column: "target_account_id", name: "fk_9571bfabc1", on_delete: :cascade
  add_foreign_key "blocks", "accounts", name: "fk_4269e03e65", on_delete: :cascade
  add_foreign_key "bookmarks", "accounts", on_delete: :cascade
  add_foreign_key "bookmarks", "statuses", on_delete: :cascade
  add_foreign_key "canonical_email_blocks", "accounts", column: "reference_account_id"
  add_foreign_key "conversation_mutes", "accounts", name: "fk_225b4212bb", on_delete: :cascade
  add_foreign_key "conversation_mutes", "conversations", on_delete: :cascade
  add_foreign_key "custom_filters", "accounts", on_delete: :cascade
  add_foreign_key "devices", "accounts", on_delete: :cascade
  add_foreign_key "devices", "oauth_access_tokens", column: "access_token_id", on_delete: :cascade
  add_foreign_key "email_domain_blocks", "email_domain_blocks", column: "parent_id", on_delete: :cascade
  add_foreign_key "encrypted_messages", "accounts", column: "from_account_id", on_delete: :cascade
  add_foreign_key "encrypted_messages", "devices", on_delete: :cascade
  add_foreign_key "favourites", "accounts", name: "fk_5eb6c2b873", on_delete: :cascade
  add_foreign_key "favourites", "statuses", name: "fk_b0e856845e", on_delete: :cascade
  add_foreign_key "featured_tags", "accounts", on_delete: :cascade
  add_foreign_key "featured_tags", "tags", on_delete: :cascade
  add_foreign_key "follow_recommendation_suppressions", "accounts", on_delete: :cascade
  add_foreign_key "follow_requests", "accounts", column: "target_account_id", name: "fk_9291ec025d", on_delete: :cascade
  add_foreign_key "follow_requests", "accounts", name: "fk_76d644b0e7", on_delete: :cascade
  add_foreign_key "follows", "accounts", column: "target_account_id", name: "fk_745ca29eac", on_delete: :cascade
  add_foreign_key "follows", "accounts", name: "fk_32ed1b5560", on_delete: :cascade
  add_foreign_key "identities", "users", name: "fk_bea040f377", on_delete: :cascade
  add_foreign_key "imports", "accounts", name: "fk_6db1b6e408", on_delete: :cascade
  add_foreign_key "invites", "users", on_delete: :cascade
  add_foreign_key "list_accounts", "accounts", on_delete: :cascade
  add_foreign_key "list_accounts", "follows", on_delete: :cascade
  add_foreign_key "list_accounts", "lists", on_delete: :cascade
  add_foreign_key "lists", "accounts", on_delete: :cascade
  add_foreign_key "login_activities", "users", on_delete: :cascade
  add_foreign_key "markers", "users", on_delete: :cascade
  add_foreign_key "media_attachments", "accounts", name: "fk_96dd81e81b", on_delete: :nullify
  add_foreign_key "media_attachments", "scheduled_statuses", on_delete: :nullify
  add_foreign_key "media_attachments", "statuses", on_delete: :nullify
  add_foreign_key "mentions", "accounts", name: "fk_970d43f9d1", on_delete: :cascade
  add_foreign_key "mentions", "statuses", on_delete: :cascade
  add_foreign_key "mutes", "accounts", column: "target_account_id", name: "fk_eecff219ea", on_delete: :cascade
  add_foreign_key "mutes", "accounts", name: "fk_b8d8daf315", on_delete: :cascade
  add_foreign_key "notifications", "accounts", column: "from_account_id", name: "fk_fbd6b0bf9e", on_delete: :cascade
  add_foreign_key "notifications", "accounts", name: "fk_c141c8ee55", on_delete: :cascade
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id", name: "fk_34d54b0a33", on_delete: :cascade
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id", name: "fk_63b044929b", on_delete: :cascade
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id", name: "fk_f5fc4c1ee3", on_delete: :cascade
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id", name: "fk_e84df68546", on_delete: :cascade
  add_foreign_key "oauth_applications", "users", column: "owner_id", name: "fk_b0988c7c0a", on_delete: :cascade
  add_foreign_key "one_time_keys", "devices", on_delete: :cascade
  add_foreign_key "poll_votes", "accounts", on_delete: :cascade
  add_foreign_key "poll_votes", "polls", on_delete: :cascade
  add_foreign_key "polls", "accounts", on_delete: :cascade
  add_foreign_key "polls", "statuses", on_delete: :cascade
  add_foreign_key "report_notes", "accounts", on_delete: :cascade
  add_foreign_key "report_notes", "reports", on_delete: :cascade
  add_foreign_key "reports", "accounts", column: "action_taken_by_account_id", name: "fk_bca45b75fd", on_delete: :nullify
  add_foreign_key "reports", "accounts", column: "assigned_account_id", on_delete: :nullify
  add_foreign_key "reports", "accounts", column: "target_account_id", name: "fk_eb37af34f0", on_delete: :cascade
  add_foreign_key "reports", "accounts", name: "fk_4b81f7522c", on_delete: :cascade
  add_foreign_key "scheduled_statuses", "accounts", on_delete: :cascade
  add_foreign_key "session_activations", "oauth_access_tokens", column: "access_token_id", name: "fk_957e5bda89", on_delete: :cascade
  add_foreign_key "session_activations", "users", name: "fk_e5fda67334", on_delete: :cascade
  add_foreign_key "status_pins", "accounts", name: "fk_d4cb435b62", on_delete: :cascade
  add_foreign_key "status_pins", "statuses", on_delete: :cascade
  add_foreign_key "status_stats", "statuses", on_delete: :cascade
  add_foreign_key "statuses", "accounts", column: "in_reply_to_account_id", name: "fk_c7fa917661", on_delete: :nullify
  add_foreign_key "statuses", "accounts", name: "fk_9bda1543f7", on_delete: :cascade
  add_foreign_key "statuses", "statuses", column: "in_reply_to_id", on_delete: :nullify
  add_foreign_key "statuses", "statuses", column: "reblog_of_id", on_delete: :cascade
  add_foreign_key "statuses_tags", "statuses", on_delete: :cascade
  add_foreign_key "statuses_tags", "tags", name: "fk_3081861e21", on_delete: :cascade
  add_foreign_key "tombstones", "accounts", on_delete: :cascade
  add_foreign_key "user_invite_requests", "users", on_delete: :cascade
  add_foreign_key "users", "accounts", name: "fk_50500f500d", on_delete: :cascade
  add_foreign_key "users", "invites", on_delete: :nullify
  add_foreign_key "users", "oauth_applications", column: "created_by_application_id", on_delete: :nullify
  add_foreign_key "web_push_subscriptions", "oauth_access_tokens", column: "access_token_id", on_delete: :cascade
  add_foreign_key "web_push_subscriptions", "users", on_delete: :cascade
  add_foreign_key "web_settings", "users", name: "fk_11910667b2", on_delete: :cascade
  add_foreign_key "webauthn_credentials", "users"

  create_view "instances", materialized: true, sql_definition: <<-SQL
      WITH domain_counts(domain, accounts_count) AS (
           SELECT accounts.domain,
              count(*) AS accounts_count
             FROM accounts
            WHERE (accounts.domain IS NOT NULL)
            GROUP BY accounts.domain
          )
   SELECT domain_counts.domain,
      domain_counts.accounts_count
     FROM domain_counts
  UNION
   SELECT domain_blocks.domain,
      COALESCE(domain_counts.accounts_count, (0)::bigint) AS accounts_count
     FROM (domain_blocks
       LEFT JOIN domain_counts ON (((domain_counts.domain)::text = (domain_blocks.domain)::text)))
  UNION
   SELECT domain_allows.domain,
      COALESCE(domain_counts.accounts_count, (0)::bigint) AS accounts_count
     FROM (domain_allows
       LEFT JOIN domain_counts ON (((domain_counts.domain)::text = (domain_allows.domain)::text)));
  SQL
  add_index "instances", ["domain"], name: "index_instances_on_domain", unique: true

  create_view "account_summaries", materialized: true, sql_definition: <<-SQL
      SELECT accounts.id AS account_id,
      mode() WITHIN GROUP (ORDER BY t0.language) AS language,
      mode() WITHIN GROUP (ORDER BY t0.sensitive) AS sensitive
     FROM (accounts
       CROSS JOIN LATERAL ( SELECT statuses.account_id,
              statuses.language,
              statuses.sensitive
             FROM statuses
            WHERE ((statuses.account_id = accounts.id) AND (statuses.deleted_at IS NULL))
            ORDER BY statuses.id DESC
           LIMIT 20) t0)
    WHERE ((accounts.suspended_at IS NULL) AND (accounts.silenced_at IS NULL) AND (accounts.moved_to_account_id IS NULL) AND (accounts.discoverable = true) AND (accounts.locked = false))
    GROUP BY accounts.id;
  SQL
  add_index "account_summaries", ["account_id"], name: "index_account_summaries_on_account_id", unique: true

  create_view "follow_recommendations", materialized: true, sql_definition: <<-SQL
      SELECT t0.account_id,
      sum(t0.rank) AS rank,
      array_agg(t0.reason) AS reason
     FROM ( SELECT account_summaries.account_id,
              ((count(follows.id))::numeric / (1.0 + (count(follows.id))::numeric)) AS rank,
              'most_followed'::text AS reason
             FROM (((follows
               JOIN account_summaries ON ((account_summaries.account_id = follows.target_account_id)))
               JOIN users ON ((users.account_id = follows.account_id)))
               LEFT JOIN follow_recommendation_suppressions ON ((follow_recommendation_suppressions.account_id = follows.target_account_id)))
            WHERE ((users.current_sign_in_at >= (now() - 'P30D'::interval)) AND (account_summaries.sensitive = false) AND (follow_recommendation_suppressions.id IS NULL))
            GROUP BY account_summaries.account_id
           HAVING (count(follows.id) >= 5)
          UNION ALL
           SELECT account_summaries.account_id,
              (sum((status_stats.reblogs_count + status_stats.favourites_count)) / (1.0 + sum((status_stats.reblogs_count + status_stats.favourites_count)))) AS rank,
              'most_interactions'::text AS reason
             FROM (((status_stats
               JOIN statuses ON ((statuses.id = status_stats.status_id)))
               JOIN account_summaries ON ((account_summaries.account_id = statuses.account_id)))
               LEFT JOIN follow_recommendation_suppressions ON ((follow_recommendation_suppressions.account_id = statuses.account_id)))
            WHERE ((statuses.id >= (((date_part('epoch'::text, (now() - 'P30D'::interval)) * (1000)::double precision))::bigint << 16)) AND (account_summaries.sensitive = false) AND (follow_recommendation_suppressions.id IS NULL))
            GROUP BY account_summaries.account_id
           HAVING (sum((status_stats.reblogs_count + status_stats.favourites_count)) >= (5)::numeric)) t0
    GROUP BY t0.account_id
    ORDER BY (sum(t0.rank)) DESC;
  SQL
  add_index "follow_recommendations", ["account_id"], name: "index_follow_recommendations_on_account_id", unique: true

  create_view "user_ips", sql_definition: <<-SQL
      SELECT t0.user_id,
      t0.ip,
      max(t0.used_at) AS used_at
     FROM ( SELECT users.id AS user_id,
              users.sign_up_ip AS ip,
              users.created_at AS used_at
             FROM users
            WHERE (users.sign_up_ip IS NOT NULL)
          UNION ALL
           SELECT session_activations.user_id,
              session_activations.ip,
              session_activations.updated_at
             FROM session_activations
          UNION ALL
           SELECT login_activities.user_id,
              login_activities.ip,
              login_activities.created_at
             FROM login_activities
            WHERE (login_activities.success = true)) t0
    GROUP BY t0.user_id, t0.ip;
  SQL
end
