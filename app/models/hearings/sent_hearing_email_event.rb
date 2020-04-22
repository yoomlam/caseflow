# frozen_string_literal: true

class SentHearingEmailEvent < CaseflowRecord
  belongs_to :hearing, polymorphic: true
  belongs_to :sent_by, class_name: "User"

  before_create :assign_sent_at_time

  # Allows all keys specified in `MailRecipient::RECIPIENT_TITLES`
  enum recipient_role: MailRecipient::RECIPIENT_TITLES.map { |key, _| [key, key.to_s] }.to_h,
       _prefix: :sent_to

  # Email types are specified in `SendEmail#email_for_recipient`
  enum email_type: (
    {
      confirmation: "confirmation",
      cancellation: "cancellation",
      updated_time_confirmation: "updated_time_confirmation"
    }
  ), _prefix: :is

  def readonly?
    !new_record?
  end

  private

  def assign_sent_at_time
    self.sent_at ||= Time.now.utc
  end
end
