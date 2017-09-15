# frozen_string_literal: true

class FollowerAccountsController < ApplicationController
  include AccountControllerConcern

  def index
    @follows = Follow.where(target_account: @account).recent.page(params[:page]).per(FOLLOW_PER_PAGE).preload(:account)

    respond_to do |format|
      format.html

      format.json do
        render json: collection_presenter, serializer: ActivityPub::FollowerCollectionSerializer, adapter: ActivityPub::Adapter, content_type: 'application/activity+json'
      end
    end
  end

  private

  def collection_presenter
    ActivityPub::AccountCollectionPresenter.new account: @account, scope: @follows
  end
end
