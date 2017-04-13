# frozen_string_literal: true

module Admin
  class ReportsController < BaseController
    before_action :set_report, except: [:index]

    def index
      @reports = filtered_reports.page(params[:page])
    end

    def show
      @statuses = Status.where(id: @report.status_ids)
    end

    def resolve
      @report.update(action_taken: true, action_taken_by_account_id: current_account.id)
      redirect_to admin_report_path(@report)
    end

    def suspend
      Admin::SuspensionWorker.perform_async(@report.target_account.id)
      Report.unresolved.where(target_account: @report.target_account).update_all(action_taken: true, action_taken_by_account_id: current_account.id)
      redirect_to admin_report_path(@report)
    end

    def silence
      @report.target_account.update(silenced: true)
      Report.unresolved.where(target_account: @report.target_account).update_all(action_taken: true, action_taken_by_account_id: current_account.id)
      redirect_to admin_report_path(@report)
    end

    def remove
      RemovalWorker.perform_async(params[:status_id].to_i)
      redirect_to admin_report_path(@report)
    end

    private

    def filtered_reports
      filtering_scope.
        includes(:account, :target_account).
        order('id desc')
    end

    def filtering_scope
      params[:resolved].present? ? Report.resolved : Report.unresolved
    end

    def set_report
      @report = Report.find(params[:id])
    end
  end
end
