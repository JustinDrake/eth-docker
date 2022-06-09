#!/bin/bash

if [[ -f /var/lib/teku/teku-keyapi.keystore && $(date +%s -r /var/lib/teku/teku-keyapi.keystore) -gt $(date +%s --date="300 days ago") ]]; then
  rm /var/lib/teku/teku-keyapi.keystore
fi

if [ ! -f /var/lib/teku/teku-keyapi.keystore ]; then
    __password=$(echo $RANDOM | md5sum | head -c 32)
    echo $__password > /var/lib/teku/teku-keyapi.password
    openssl req -new --newkey rsa:2048 -nodes -keyout /var/lib/teku/teku-keyapi.key -out /var/lib/teku/teku-keyapi.csr -subj "/CN=127.0.0.1"
    openssl x509 -req -days 365 -in  /var/lib/teku/teku-keyapi.csr -signkey  /var/lib/teku/teku-keyapi.key -out  /var/lib/teku/teku-keyapi.crt
    openssl pkcs12 -export -in /var/lib/teku/teku-keyapi.crt -inkey /var/lib/teku/teku-keyapi.key -out /var/lib/teku/teku-keyapi.keystore -name teku-keyapi -passout pass:$__password
fi

if [ -n "${JWT_SECRET}" ]; then
  echo -n ${JWT_SECRET} > /var/lib/teku/secrets/jwtsecret
  echo "JWT secret was supplied in .env"
fi

# Check whether we should rapid sync
if [ -n "${RAPID_SYNC_URL:+x}" ]; then
  __rapid_sync="--initial-state=${RAPID_SYNC_URL}/eth/v1/debug/beacon/states/finalized"
else
  __rapid_sync=""
fi

# Check whether we should override TTD
if [ -n "${OVERRIDE_TTD}" ]; then
  __override_ttd="--Xnetwork-total-terminal-difficulty-override=${OVERRIDE_TTD}"
  echo "Overriding TTD to ${OVERRIDE_TTD}"
else
  __override_ttd=""
fi

# Check whether we should use MEV Boost
if [ "${MEV_BOOST}" = "true" ]; then
  __mev_boost="--Xvalidators-proposer-blinded-blocks-enabled=true --Xvalidators-registration-default-enabled=true --Xeb-endpoint=http://mev-boost:18550"
  echo "MEV Boost enabled"
else
  __mev_boost=""
fi

exec $@ ${__mev_boost} ${__rapid_sync} ${__override_ttd}
