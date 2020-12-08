// External Dependencies
import React from 'react';
import PropTypes from 'prop-types';

// Local Dependencies
import { CannotSaveAlert } from 'components/reader/DocumentViewer/CannotSaveAlert';
import SearchableDropdown from 'app/components/SearchableDropdown';
import { formatTagValue } from 'utils/reader';

/**
 * Issue Tags Component for searching Document Issue Tags
 * @param {Object} props -- Contains details to search for document tags
 */
export const IssueTags = ({ errors, doc, changeTags, tagOptions, currentDocument }) => (
  <div className="cf-issue-tag-sidebar">
    {errors?.tag?.visible && <CannotSaveAlert />}
    <SearchableDropdown
      key={doc.id}
      name="tags"
      label="Select or tag issues"
      multi
      dropdownStyling={{ position: 'relative' }}
      creatable
      options={tagOptions}
      placeholder=""
      value={currentDocument.tags ? formatTagValue(currentDocument.tags) : []}
      onChange={changeTags}
    />
  </div>
);

IssueTags.propTypes = {
  doc: PropTypes.object,
  changeTags: PropTypes.func,
  errors: PropTypes.object,
  tagOptions: PropTypes.array,
  currentDocument: PropTypes.object
};
