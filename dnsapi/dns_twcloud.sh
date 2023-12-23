#!/usr/bin/bash
# Author: coralhl@gmail.com
# 23 Dec 2023

# Values to export:
# export TWC_Token="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Sometimes cloudflare / google doesn't pick new dns records fast enough.
# You can add --dnssleep XX to params as workaround.

########  Public functions #####################

#Usage: dns_myapi_add   _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_twcloud_add() {
  fulldomain="${1}"
  txtvalue="${2}"
  _debug "Calling: dns_twcloud_add() '${fulldomain}' '${txtvalue}'"

  _TWC_credentials || return 1

  _TWC_get_domain || return 1
  _debug "Found suitable domain: $domain"

  data='{"subdomain":"'${subdomain}'","type":"TXT","value":"'${txtvalue}'"}'
  _debug "Data: $data"
  uri="https://api.timeweb.cloud/api/v1/domains/${domain}/dns-records"
  result="$(_post "${data}" "${uri}" | _normalizeJson)"
  _debug "Result: $result"

  if _contains "$result" '"dns_record":'; then
    _info "Added, OK"
    return 0
  else
    _err "Can't add $subdomain to $domain."
    return 1
  fi
}

#Usage: dns_myapi_rm   _acme-challenge.www.domain.com
dns_twcloud_rm() {
  fulldomain="${1}"
  _debug "Calling: dns_twcloud_rm() '${fulldomain}'"

  _TWC_credentials || return 1

  _TWC_get_domain "$fulldomain" || return 1
  _debug "Found suitable domain: $domain"

  _TWC_get_record_ids "${domain}" "${subdomain}" || return 1
  _debug "Record_ids: $record_ids"

  for record_id in $record_ids; do
    uri="https://api.timeweb.cloud/api/v1/domains/${domain}/dns-records/${record_id}"
    result="$(_post "" "${uri}" "" "DELETE" | _normalizeJson)"
    _debug "Result: $result"

    if ! _contains "$result" ''; then
      _info "Can't remove $subdomain from $domain."
    fi
  done
}

####################  Private functions below ##################################

_TWC_get_domain() {
  subdomain_start=1
  while true; do
    domain_start=$(_math $subdomain_start + 1)
    domain=$(echo "$fulldomain" | cut -d . -f "$domain_start"-)
    subdomain=$(echo "$fulldomain" | cut -d . -f -"$subdomain_start")

    _debug "Checking domain $domain"
    if [ -z "$domain" ]; then
      return 1
    fi

    uri="https://api.timeweb.cloud/api/v1/domains/$domain"
    result="$(_get "${uri}" | _normalizeJson)"
    _debug "Result: $result"

    if _contains "$result" '"domain":'; then
      return 0
    fi
    subdomain_start=$(_math $subdomain_start + 1)
  done
}

_TWC_credentials() {
  if [ -z "${TWC_Token}" ]; then
    TWC_Token=""
    _err "You need to export TWC_Token=xxxxxxxxxxxxxxxxx."
    _err "You can get it at https://timeweb.cloud/my/api-keys"
    return 1
  else
    _saveaccountconf TWC_Token "${TWC_Token}"
  fi
  export _H1="Content-Type: application/json"
  export _H2="Authorization: Bearer $TWC_Token"
}

_TWC_get_record_ids() {
  _debug "Check existing records for $subdomain"

  uri="https://api.timeweb.cloud/api/v1/domains/${domain}/dns-records"
  result="$(_get "${uri}" | _normalizeJson)"
  _debug "Result: $result"

  if ! _contains "$result" '"dns_records":'; then
    return 1
  fi

  record_ids=$(echo $result | awk -F"\"subdomain\":\"$subdomain\"" '{print$2}' | awk -F",\"type\":\"TXT\"" '{print$1}' | awk -F"\"id\":" '{print$2}')
}
