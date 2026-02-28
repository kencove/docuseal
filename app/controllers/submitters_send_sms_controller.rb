# frozen_string_literal: true

class SubmittersSendSmsController < ApplicationController
  load_and_authorize_resource :submitter, id_param: :submitter_slug, find_by: :slug

  def create
    RateLimit.call("sms_send:#{current_user.id}", limit: 10, ttl: 1.hour, enabled: true)

    if SubmissionEvent.exists?(submitter: @submitter,
                               event_type: 'send_sms',
                               created_at: 10.hours.ago..Time.current)
      return redirect_back(fallback_location: submission_path(@submitter.submission),
                           alert: I18n.t('sms_has_been_sent_already'))
    end

    SendSubmitterInvitationSmsJob.perform_async('submitter_id' => @submitter.id)

    @submitter.sent_at ||= Time.current
    @submitter.save!

    redirect_back(fallback_location: submission_path(@submitter.submission), notice: I18n.t('sms_has_been_sent'))
  rescue RateLimit::LimitApproached
    redirect_back(fallback_location: submission_path(@submitter.submission),
                  alert: I18n.t('too_many_requests_try_again_later'))
  end
end
