import React, { useCallback, useEffect } from 'react';
import PropTypes from 'prop-types';
import styled from 'styled-components';
import { Controller, useFormContext } from 'react-hook-form';

import SearchableDropdown from 'app/components/SearchableDropdown';
import RadioField from 'app/components/RadioField';
import TextField from 'app/components/TextField';
import AddressForm from 'app/components/AddressForm';
import Address from 'app/queue/components/Address';
import * as Constants from '../constants';
import { ADD_CLAIMANT_PAGE_DESCRIPTION } from 'app/../COPY';
import { fetchAttorneys, formatAddress } from './utils';
import { debounce } from 'lodash';

const relationshipOpts = [
  { value: 'attorney', label: 'Attorney (previously or currently)' },
  { value: 'child', label: 'Child' },
  { value: 'spouse', label: 'Spouse' },
  { value: 'other', label: 'Other' },
];

const partyTypeOpts = [
  { displayText: 'Organization', value: 'organization' },
  { displayText: 'Individual', value: 'individual' },
];

const getAttorneyClaimantOpts = async (search = '', asyncFn) => {
  // Enforce minimum search length (we'll simply return empty array rather than throw error)
  if (search.length < 3) {
    return [];
  }

  const res = await asyncFn(search);
  const options = res.map((item) => ({
    label: item.name,
    value: item.participant_id,
    address: formatAddress(item.address),
  }));

  options.push({ label: 'Name not listed', value: 'not_listed' });

  return options;
};

// We'll show all items returned from the backend instead of using default substring matching
const filterOption = () => true;

export const AddClaimantForm = ({
  onAttorneySearch = fetchAttorneys,
  onSubmit,
}) => {
  const methods = useFormContext();
  const { control, register, watch, handleSubmit, setValue } = methods;

  const watchPartyType = watch('partyType');
  const watchRelationship = watch('relationship');

  const showIndividualNameFields =
    watchPartyType === 'individual' ||
    ['spouse', 'child'].includes(watchRelationship);
  const listedAttorney = watch('listedAttorney');
  const attorneyNotListed = listedAttorney?.value === 'not_listed';
  const showPartyType = watchRelationship === 'other' || attorneyNotListed;
  const showAdditionalFields =
    watchPartyType || ['spouse', 'child'].includes(watchRelationship);

  const asyncFn = useCallback(
    debounce((search, callback) => {
      getAttorneyClaimantOpts(search, onAttorneySearch).then((res) =>
        callback(res)
      );
    }, 250),
    [onAttorneySearch]
  );

  useEffect(() => {
    if (watchRelationship !== 'attorney') {
      setValue('listedAttorney', null);
    }
  }, [watchRelationship]);

   useEffect(() => {
    if (['spouse', 'child'].includes(watchRelationship)) {
      setValue('partyType', "Individual");
    }
  }, [watchRelationship]);

  return (
    <>
      <h1>Add Claimant</h1>
      <p>{ADD_CLAIMANT_PAGE_DESCRIPTION}</p>
      <form onSubmit={handleSubmit(onSubmit)}>
        <Controller
          control={control}
          name="relationship"
          render={({ onChange, ...rest }) => (
            <SearchableDropdown
              {...rest}
              label="Relationship to the Veteran"
              options={relationshipOpts}
              onChange={(valObj) => {
                onChange(valObj);
                setValue('relationship', valObj?.value);
              }}
              strongLabel
            />
          )}
        />
        <br />
        {watchRelationship === 'attorney' && (
          <>
            <Controller
              control={control}
              name="listedAttorney"
              defaultValue={null}
              render={({ ...rest }) => (
                <SearchableDropdown
                  {...rest}
                  label="Claimant's name"
                  filterOption={filterOption}
                  async={asyncFn}
                  defaultOptions
                  debounce={250}
                  strongLabel
                  isClearable
                  placeholder="Type to search..."
                />
              )}
            />
          </>
        )}

        {listedAttorney?.address && (
          <div>
            <ClaimantAddress>
              <strong>Claimant's address</strong>
            </ClaimantAddress>
            <br />
            <Address address={listedAttorney?.address} />
          </div>
        )}

        {showPartyType && (
          <RadioField
            name="partyType"
            label="Is the claimant an organization or individual?"
            inputRef={register}
            strongLabel
            vertical
            options={partyTypeOpts}
          />
        )}
        <br />
        {showIndividualNameFields && (
          <>
            <FieldDiv>
              <TextField
                name="firstName"
                label="First name"
                inputRef={register}
                strongLabel
              />
            </FieldDiv>
            <FieldDiv>
              <TextField
                name="middleName"
                label="Middle name/initial"
                inputRef={register}
                optional
                strongLabel
              />
            </FieldDiv>
            <FieldDiv>
              <TextField
                name="lastName"
                label="Last name"
                inputRef={register}
                optional
                strongLabel
              />
            </FieldDiv>
            <Suffix>
              <TextField
                name="suffix"
                label="Suffix"
                inputRef={register}
                optional
                strongLabel
              />
            </Suffix>
          </>
        )}
        {watchPartyType === 'organization' && (
          <TextField
            name="organization"
            label="Organization name"
            inputRef={register}
            strongLabel
          />
        )}
        {showAdditionalFields && (
          <>
            <AddressForm {...methods} />
            <FieldDiv>
              <TextField
                name="email"
                label="Claimant email"
                inputRef={register}
                optional
                strongLabel
              />
            </FieldDiv>
            <PhoneNumber>
              <TextField
                name="phoneNumber"
                label="Phone number"
                inputRef={register}
                optional
                strongLabel
              />
            </PhoneNumber>
          </>
        )}
        {(showAdditionalFields || listedAttorney) && (
          <RadioField
            options={Constants.BOOLEAN_RADIO_OPTIONS}
            vertical
            inputRef={register}
            label="Do you have a VA Form 21-22 for this claimant?"
            name="vaForm"
            strongLabel
          />
        )}
      </form>
    </>
  );
};

AddClaimantForm.propTypes = {
  onAttorneySearch: PropTypes.func,
  onBack: PropTypes.func,
  onSubmit: PropTypes.func,
};

const FieldDiv = styled.div`
  margin-bottom: 1.5em;
`;

const Suffix = styled.div`
  max-width: 8em;
`;

const PhoneNumber = styled.div`
  width: 240px;
  margin-bottom: 2em;
`;

const ClaimantAddress = styled.div`
  margin-top: 1.5em;
`;
