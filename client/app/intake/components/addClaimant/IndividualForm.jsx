import React, { memo }  from 'react';
import styled from 'styled-components';
import * as Constants from '../../constants';

import RadioField from 'app/components/RadioField';
import TextField from 'app/components/TextField';
import AddressForm from 'app/components/AddressForm';

export const IndividualForm = memo(
  ({ register, formState: { isDirty } }) => (
    <React.Fragment>
      <br />
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
      <AddressForm />
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
      <RadioField
        options={Constants.BOOLEAN_RADIO_OPTIONS}
        vertical
        inputRef={register}
        label="Do you have a VA Form 21-22 for this claimant?"
        name="vaForm"
        strongLabel
      />
  </React.Fragment>
  ),
  (prevProps, nextProps) =>
    prevProps.formState.isDirty === nextProps.formState.isDirty
);

const Suffix = styled.div`
  max-width: 8em;
`;

const PhoneNumber = styled.div`
  width: 240px;
  margin-bottom: 2em;
`;

const FieldDiv = styled.div`
  margin-bottom: 1.5em;
`;

export default IndividualForm;
