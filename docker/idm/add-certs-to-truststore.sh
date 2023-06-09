#!/usr/bin/env bash

set -e
set -o pipefail

IDM_DEFAULT_TRUSTSTORE=${IDM_DEFAULT_TRUSTSTORE:-$JAVA_HOME/lib/security/cacerts}
# If a $IDM_PEM_TRUSTSTORE is provided, import it into the truststore. Otherwise, do nothing
if [ -f "$IDM_DEFAULT_TRUSTSTORE" ] && [ -f "$IDM_PEM_TRUSTSTORE" ]; then
    TRUSTSTORE_PATH="${TRUSTSTORE_PATH:-/home/forgerock/amtruststore}"
    TRUSTSTORE_PASSWORD="${TRUSTSTORE_PASSWORD:-changeit}"
    echo "Copying ${IDM_DEFAULT_TRUSTSTORE} to ${TRUSTSTORE_PATH}"
    # Calculate the number of certs in the PEM file
    CERTS=$(grep 'END CERTIFICATE' $IDM_PEM_TRUSTSTORE| wc -l)
    echo "Found (${CERTS}) certificates in $IDM_PEM_TRUSTSTORE"
    echo "Importing (${CERTS}) certificates into ${TRUSTSTORE_PATH}"
    # For every cert in the PEM file, extract it and import into the JKS truststore
    EXISTING_CERTS=$(keytool -list -keystore $TRUSTSTORE_PATH -storepass $TRUSTSTORE_PASSWORD | grep imported | wc -l)
    echo "$EXISTING_CERTS certs already trusted"
    C=0
    for N in $(seq $EXISTING_CERTS $(($EXISTING_CERTS + $CERTS - 1))); do
        ALIAS="imported-certs-$N" 
        cat $IDM_PEM_TRUSTSTORE |
            awk "n==$C { print }; /END CERTIFICATE/ { n++ }" |
            keytool -noprompt -importcert -trustcacerts -storetype JKS \
                    -alias "${ALIAS}" -keystore "${TRUSTSTORE_PATH}" \
                    -storepass "${TRUSTSTORE_PASSWORD}"
        echo "$ALIAS imported"
        C=$(($C + 1))
    done
    echo "Import complete!"
else
    echo "Nothing was imported to the truststore. Check ENVs IDM_DEFAULT_TRUSTSTORE and IDM_PEM_TRUSTSTORE"
    exit -1
fi
