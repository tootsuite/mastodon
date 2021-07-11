import axios from 'axios';
import LinkHeader from 'http-link-header';
import ready from './ready';

export const getLinks = response => {
  const value = response.headers.link;

  if (!value) {
    return { refs: [] };
  }

  return LinkHeader.parse(value);
};

const csrfHeader = {};

const setCSRFHeader = () => {
  const csrfToken = document.querySelector('meta[name=csrf-token]');

  if (csrfToken) {
    csrfHeader['X-CSRF-Token'] = csrfToken.content;
  }
};

ready(setCSRFHeader);

const authorizationHeaderFromState = getState => {
  const accessToken = getState && getState().getIn(['meta', 'access_token'], '');

  if (!accessToken) {
    return {};
  }

  return {
    'Authorization': `Bearer ${accessToken}`,
  };
};

export default getState => axios.create({
  headers: {
    ...csrfHeader,
    ...authorizationHeaderFromState(getState),
  },

  transformResponse: [function (data) {
    try {
      return JSON.parse(data);
    } catch(Exception) {
      return data;
    }
  }],
});
