class LegacyHearing < ApplicationRecord
  include CachedAttributes
  include AssociatedVacolsModel
  include HearingConcern
  include AppealConcern

  after_save :save_hearing
  before_destroy :destroy_hearing

  vacols_attr_accessor :veteran_first_name, :veteran_middle_initial, :veteran_last_name
  vacols_attr_accessor :appellant_first_name, :appellant_middle_initial, :appellant_last_name
  vacols_attr_accessor :date, :type, :venue_key, :vacols_record, :disposition
  vacols_attr_accessor :aod, :hold_open, :transcript_requested, :notes, :add_on
  vacols_attr_accessor :transcript_sent_date, :appeal_vacols_id
  vacols_attr_accessor :representative_name, :representative
  vacols_attr_accessor :regional_office_key, :master_record
  vacols_attr_accessor :docket_number, :appeal_type, :appellant_address_line_1
  vacols_attr_accessor :appellant_address_line_2, :appellant_city, :appellant_state
  vacols_attr_accessor :appellant_zip, :appellant_country, :room, :bva_poc, :judge_id

  belongs_to :appeal, class_name: "LegacyAppeal"
  belongs_to :user # the judge
  has_many :hearing_views, foreign_key: :hearing_id
  has_many :appeal_stream_snapshots, foreign_key: :hearing_id

  # this is used to cache appeal stream for hearings
  # when fetched intially.
  has_many :appeals, class_name: "LegacyAppeal", through: :appeal_stream_snapshots

  CO_HEARING = "Central".freeze
  VIDEO_HEARING = "Video".freeze

  def venue
    self.class.venues[venue_key]
  end

  def location
    (type == :central) ? "Board of Veterans' Appeals in Washington, DC" : venue[:label]
  end

  def closed?
    !!disposition
  end

  def no_show?
    disposition == :no_show
  end

  def held?
    disposition == :held
  end

  def scheduled_pending?
    date && !closed?
  end

  def held_open?
    hold_open && hold_open > 0
  end

  def hold_release_date
    return unless held_open?
    date.to_date + hold_open.days
  end

  def no_show_excuse_letter_due_date
    date.to_date + 15.days
  end

  def active_appeal_streams
    return appeals if appeals.any?
    appeals << self.class.repository.appeals_ready_for_hearing(appeal.vbms_id)
  end

  def update_caseflow_and_vacols(hearing_hash)
    ActiveRecord::Base.multi_transaction do
      self.class.repository.update_vacols_hearing!(vacols_record, hearing_hash)
      update!(hearing_hash)
    end
  end

  def regional_office_timezone
    HearingMapper.timezone(regional_office_key)
  end

  def readable_location
    if request_type == LegacyHearing::CO_HEARING
      return "Washington DC"
    end

    regional_office_name
  end

  # rubocop:disable Metrics/MethodLength
  def vacols_attributes
    {
      date: date,
      type: type,
      venue_key: venue_key,
      vacols_record: vacols_record,
      disposition: disposition,
      aod: aod,
      hold_open: hold_open,
      transcript_requested: transcript_requested,
      transcript_sent_date: transcript_sent_date,
      notes: notes,
      add_on: add_on,
      representative: representative,
      representative_name: representative_name,
      regional_office_key: regional_office_key,
      master_record: master_record,
      veteran_first_name: veteran_first_name,
      veteran_middle_initial: veteran_middle_initial,
      veteran_last_name: veteran_last_name,
      appellant_first_name: appellant_first_name,
      appellant_middle_initial: appellant_middle_initial,
      appellant_last_name: appellant_last_name,
      appeal_vacols_id: appeal_vacols_id

    }
  end

  cache_attribute :cached_number_of_documents do
    begin
      number_of_documents
    rescue Caseflow::Error::EfolderError, VBMS::HTTPError
      nil
    end
  end

  delegate \
    :veteran_age, \
    :veteran_sex, \
    :vbms_id, \
    :number_of_documents, \
    :number_of_documents_after_certification, \
    :veteran,  \
    :sanitized_vbms_id, \
    :docket_name,
    to: :appeal, allow_nil: true

  delegate :vacols_id, to: :appeal, prefix: true

  def to_hash(current_user_id)
    serializable_hash(
      methods: [
        :date,
        :request_type,
        :disposition,
        :aod,
        :transcript_requested,
        :hold_open,
        :notes,
        :add_on,
        :master_record,
        :representative,
        :representative_name,
        :regional_office_name,
        :regional_office_timezone,
        :venue,
        :veteran_name,
        :veteran_mi_formatted,
        :appellant_last_first_mi,
        :appellant_mi_formatted,
        :veteran_fi_last_formatted,
        :vbms_id,
        :current_issue_count,
        :prepped,
        :docket_number,
        :docket_name,
        :appeal_type,
        :appellant_address_line_1,
        :appellant_city,
        :appellant_state,
        :appellant_zip,
        :readable_location,
        :appeal_vacols_id
      ],
      except: :military_service
    ).merge(
      viewed_by_current_user: hearing_views.all.any? do |hearing_view|
        hearing_view.user_id == current_user_id
      end
    )
  end

  def fetch_veteran_age
    veteran_age
  rescue Module::DelegationError
    nil
  end

  def fetch_veteran_sex
    veteran_sex
  rescue Module::DelegationError
    nil
  end

  def to_hash_for_worksheet(current_user_id)
    serializable_hash(
      methods: [:appeal_id,
                :user,
                :summary,
                :appeal_vacols_id,
                :appeals_ready_for_hearing,
                :cached_number_of_documents,
                :appellant_city,
                :appellant_state,
                :military_service,
                :appellant_mi_formatted,
                :veteran_mi_formatted,
                :veteran_fi_last_formatted,
                :sanitized_vbms_id]
    ).merge(
      to_hash(current_user_id)
    ).merge(
      veteran_sex: fetch_veteran_sex,
      veteran_age: fetch_veteran_age
    )
  end

  def appeals_ready_for_hearing
    active_appeal_streams.map(&:attributes_for_hearing)
  end

  def current_issue_count
    active_appeal_streams.map(&:worksheet_issues).flatten
      .reject do |issue|
      issue.deleted? || (issue.disposition && issue.disposition =~ /Remand/ && issue.from_vacols?)
    end
      .count
  end

  # If we do not yet have the military_service saved in Caseflow's DB, then
  # we want to fetch it from BGS, save it to the DB, then return it
  def military_service
    super || begin
      update_attributes(military_service: veteran.periods_of_service.join("\n")) if persisted? && veteran
      super
    end
  end

  def save_hearing
    hearing = Hearing.find(attributes["id"])
    hearing.update!(attributes)
  rescue ActiveRecord::RecordNotFound
    Hearing.create!(attributes)
  end

  def destroy_hearing
    Hearing.find(attributes["id"]).destroy!
  end

  class << self
    def venues
      RegionalOffice::CITIES.merge(RegionalOffice::SATELLITE_OFFICES)
    end

    def repository
      HearingRepository
    end

    def user_nil_or_assigned_to_another_judge?(user, vacols_css_id)
      user.nil? || (user.css_id != vacols_css_id)
    end

    def assign_or_create_from_vacols_record(vacols_record, fetched_hearing = nil)
      transaction do
        hearing = fetched_hearing ||
                  find_or_initialize_by(vacols_id: vacols_record.hearing_pkseq)

        # update hearing if user is nil, it's likely when the record doesn't exist and is being created
        # or if vacols record css is different from
        # who it's assigned to in the db.
        if user_nil_or_assigned_to_another_judge?(hearing.user, vacols_record.css_id)
          hearing.update(
            appeal: LegacyAppeal.find_or_create_by(vacols_id: vacols_record.folder_nr),
            user: User.find_by(css_id: vacols_record.css_id)
          )
        end

        hearing
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
