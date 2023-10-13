#!/bin/bash
# Update the NAKIVO Transporter SSL certificate

# catcerts.sh assumes the following locations:
# crt: /etc/ssl/certs/
# key: /etc/ssl/private/
# These are defaults for ipa-getcert on Ubuntu.
# If you use different paths, see https://github.com/dmgeurts/catcerts

## Paths & variables
BASE="/opt/nakivo/transporter"
PEM="$BASE/certificate.pem"

/usr/local/bin/catcerts.sh -K -o "$PEM" "$(hostname).crt"
chown bhsvc "$PEM"
systemctl restart nkv-bhsvc.service
