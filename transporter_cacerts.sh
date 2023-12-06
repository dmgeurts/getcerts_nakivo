#!/bin/bash
# Update the NAKIVO Transporter SSL/TLS Trust store with a corporate root CA

## Paths & variables
BASE="/opt/nakivo/transporter"
KEYTOOL="$BASE/java/jre/bin/keytool"
KEYSTORE="$BASE/java/jre/lib/security/cacerts"
CA_CRT="/etc/ipa/ca.crt"

## Corporate variable
ALIAS="cn=company_root_ca,ou=ipa,o=company,c=tld"

## This script must be run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Check that source files are available
if [ ! -f "$CA_CRT" ]; then
    echo "ERROR: CA certificate not found: $CA_CRT"
    exit 2
fi

# Backup the old keystore
if [ ! -f "${KEYSTORE}.old" ]; then
    cp "$KEYSTORE" "${KEYSTORE}.old"
    echo "Backup of original cacerts file created."
    BKP="yes"
else
    echo "Backup of cacerts file found, not replaced."
    BKP="no"
fi

# Update the JAVA Trust store
if "$KEYTOOL" -importcert -file "$CA_CRT" -keystore "$KEYSTORE" -storepass "changeit" -noprompt -alias "$ALIAS"; then
    echo "SUCCESS: JAVA Trust store updated. Now restarting the Transporter."
    if systemctl restart nkv-bhsvc.service; then
        # Should find a better test of Transporter status
        echo "NAKIVO Transporter restarted"
    fi
else
    echo "ERROR: Update of JAVA Trust store failed."
    # Cleanup
    if [[ "$BKP" == "yes" ]]; then
        cp "${KEYSTORE}.old" "$KEYSTORE"
        echo "Reverted $KEYSTORE, next restarting the Transporter."
        if systemctl restart nkv-bhsvc.service; then
            # Should find a better test of Transporter status
            echo "NAKIVO Transporter restarted"
        fi
    else
        echo "Check the Transporter service. Manual intervention may be required."
    fi
fi
