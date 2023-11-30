#!/bin/bash
# Update the NAKIVO Director SSL/TLS certificate

## Paths & variables
BASE="/opt/nakivo/director"
KEYTOOL="$BASE/jre/bin/keytool"
KEYSTORE="$BASE/tomcat/cert/.keystore"
TOMCAT_CFG="$BASE/tomcat/conf/server-linux.xml"
CA_CRT="/etc/ipa/ca.crt"

## System defaults
# Ubuntu:
DEF_KEY_PATH="/etc/ssl/private"
DEF_CRT_PATH="/etc/ssl/certs"

## Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [-h] -K | -k KEY <certificate>
This script creates a keystore for NAKIVO Director.

    <certificate>   If no path is given, $DEF_CRT_PATH will be assumed.
    -K | -k KEY     Certificate key file.
                    -K assumes: $DEF_KEY_PATH/<certificate>.key
    -h              Display this help and exit.
EOF
}

## Fixed variables
OPTIND=1

## Read/interpret optional arguments
while getopts Kk:c:o:h opt; do
    case $opt in
        K)  KEY="yes"
            ;;
        k)  KEY=$OPTARG
            ;;
        *)  show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --

## This script must be run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Check that source files are available
if [ -z "$@" ]; then
    printf "ERROR: No certificate given.\n\n"
    show_help >&2
    exit 1
else
    CRT="$@"
    if [[ "$(dirname "$CRT")" == "." ]]; then
        CRT="$DEF_CRT_PATH/$CRT"
    fi
    if [ ! -f "$CRT" ]; then
        echo "ERROR: Certificate not found: $CRT"
        exit 2
    elif [ -n "$KEY" ]; then
        if [[ "$KEY" == "yes" ]]; then
            # -K parsed
            KEY="$DEF_KEY_PATH/$(basename "${CRT%.*}").key"
        elif [[ "$(dirname "$KEY")" == "." ]]; then
            # -k with filename parsed
            KEY="$DEF_KEY_PATH/$KEY"
        fi
        # -k with filename and path parsed, or constructed above
        if [ ! -f "$KEY" ]; then
            echo "ERROR: Key not found: $KEY"
            exit 2
        fi
        echo "Using key: $KEY"
    else
        echo "ERROR: A key file must be parsed, found neither."
        exit 1
    fi
fi

# Find the configured keystore password
PASS=$(grep -oP 'keystorePass=\K\S+' "$TOMCAT_CFG" | xargs)

# Create a PKCS12 file containing the certificate and key for the Director UI
openssl pkcs12 -export -in "$CRT" -inkey "$KEY" -out "${CRT%.*}.p12" -name tomcat -CAfile "$CA_CRT" -caname root -passout pass:$PASS

if "$KEYTOOL" -importkeystore -keystore "/tmp/nkv-dirsvc.keystore" -storepass $PASS -srcstorepass $PASS -noprompt -srcstoretype PKCS12 -srckeystore "${CRT%.*}.p12" -alias "tomcat"; then
    echo "SUCCESS: New keystore created. Now restarting the director."
    # Backup the current certificate keystore
    mv $KEYSTORE ${KEYSTORE}.old
    # Install the new keystore file
    mv "/tmp/nkv-dirsvc.keystore" $KEYSTORE
    if systemctl restart nkv-dirsvc.service; then
        # Should find a better test of Director status
        echo "NAKIVO Director restarted"
    fi
else
    echo "ERROR: Keystore creation failed."
    # Cleanup
    rm "/tmp/nkv-dirsvc.keystore"
    echo "### PKCS12 certificate file left here: ${CRT%.*}.p12"
fi
