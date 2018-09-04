import React from 'react';
import _ from 'lodash';
import COPY from '../../../COPY.json';
import { css } from 'glamor';
import AppSegment from '@department-of-veterans-affairs/caseflow-frontend-toolkit/components/AppSegment';
import Table from '../../components/Table';
import { formatDate } from '../../util/DateUtil';
import Link from '@department-of-veterans-affairs/caseflow-frontend-toolkit/components/Link';
import Button from '../../components/Button';
import PropTypes from 'prop-types';
import BasicDateRangeSelector from '../../components/BasicDateRangeSelector';
import InlineForm from '../../components/InlineForm';
import { CSVLink } from 'react-csv';

const hearingSchedStyling = css({
  marginTop: '70px'
});

export default class ListSchedule extends React.Component {

  render() {
    const {
      hearingSchedule
    } = this.props;

    const hearingScheduleColumns = [
      {
        header: 'Date',
        align: 'left',
        valueName: 'hearingDate'
      },
      {
        header: 'Type',
        align: 'left',
        valueName: 'hearingType'
      },
      {
        header: 'Regional Office',
        align: 'left',
        valueName: 'regionalOffice'
      },
      {
        header: 'Room',
        align: 'left',
        valueName: 'room'
      },
      {
        header: 'VLJ',
        align: 'left',
        valueName: 'vlj'
      }
    ];

    const hearingScheduleRows = _.map(hearingSchedule, (hearingDay) => ({
      hearingDate: formatDate(hearingDay.hearingDate),
      hearingType: hearingDay.hearingType,
      regionalOffice: hearingDay.regionalOffice,
      room: hearingDay.roomInfo,
      vlj: hearingDay.judgeName
    }));

    const removeCoDuplicates = _.uniqWith(hearingScheduleRows, _.isEqual);

    const fileName = `HearingSchedule ${this.props.startDateValue}-${this.props.endDateValue}.csv`;

    return <AppSegment filledBackground>
      <h1 className="cf-push-left">{COPY.HEARING_SCHEDULE_VIEW_PAGE_HEADER}</h1>
      <span className="cf-push-right"><Link button="primary" to="/schedule/build">Build schedule</Link></span>
      <div className="cf-help-divider" {...hearingSchedStyling} ></div>
      <div className="cf-push-left">
        <InlineForm>
          <BasicDateRangeSelector
            startDateName="fromDate"
            startDateValue={this.props.startDateValue}
            startDateLabel={COPY.HEARING_SCHEDULE_VIEW_START_DATE_LABEL}
            endDateName="toDate"
            endDateValue={this.props.endDateValue}
            endDateLabel={COPY.HEARING_SCHEDULE_VIEW_END_DATE_LABEL}
            onStartDateChange={this.props.startDateChange}
            onEndDateChange={this.props.endDateChange}
          />
          &nbsp;&nbsp;&nbsp;&nbsp;
          <div {...hearingSchedStyling}>
            <Link
              name="apply"
              to="/schedule"
              onClick={this.props.onApply}>
              {COPY.HEARING_SCHEDULE_VIEW_PAGE_APPLY_LINK}
            </Link>
          </div>
        </InlineForm>
      </div>
      <div className="cf-push-right" {...hearingSchedStyling}>
        <Button
          classNames={['usa-button-outline']}>
          <CSVLink
            data={removeCoDuplicates}
            target="_blank"
            filename={fileName}>
            Download current view
          </CSVLink>
        </Button>
      </div>
      <div {...hearingSchedStyling}>
        <Table
          columns={hearingScheduleColumns}
          rowObjects={removeCoDuplicates}
          summary="hearing-schedule"
        />
      </div>
    </AppSegment>;
  }
}

ListSchedule.propTypes = {
  hearingSchedule: PropTypes.shape({
    hearingDate: PropTypes.string,
    hearingType: PropTypes.string,
    regionalOffice: PropTypes.string,
    roomInfo: PropTypes.string,
    judgeId: PropTypes.string,
    judgeName: PropTypes.string,
    updatedOn: PropTypes.string,
    updatedBy: PropTypes.string
  }),
  startDateValue: PropTypes.string,
  endDateValue: PropTypes.string,
  startDateChange: PropTypes.func,
  endDateChange: PropTypes.func,
  onApply: PropTypes.func
};
