# getcerts_nakivo
Automate Nakivo FreeIPA certificate renewal using ipa-getcert. Though Nakivo's API does have hooks for SSL certificate management (com.company.product.api.services.sslcertificate), it requires an Enterprise Plus license.

# FreeIPA Certificates for Nakivo

NAKIVO devices use self-signed certificates out of the box. And although one can deploy the Transporter with a pem certificate during installation time. There's no easy way to automate the process when certificates need to be renewed. The Director does support a comprehensive API, but sadly this is a licensed feature. I wish they would at least permit an SSL certificate to be updated on the other licenses, but alas, not today.

## Some facts about NAKIVO certificate usage

### Director

- The certificate and key are stored in the tomcat keystore: `/opt/nakivo/director/tomcat/cert/.keystore`.
- This file is password protected, but the password can be found here: `/opt/nakivo/director/tomcat/conf/server-linux.xml`. Look for the value of `keystorePass="********"`.

### Transporter

- Firstly, a bug, when parsing a certificate to the installer, the ownership isn't changed to user `bhsvc`. Thus this must be corrected and the transports will need to be restarted to get it to use the given certificate.
- The pem certificate file must include the key.
- The pem certificate file is stored here: `/opt/nakivo/transporter/certificate.pem`.

## Some scripts to help automate it all

- `./director_chssl.sh`. Will take a certificate and a key file, generate a PKCS12 file with them and use it to create a new keystore file. It will then replace the active keystore and restart the Director service.
- `./transporter_chpem.sh` Will take a certificate and key file, and store them concatenated to `/opt/nakivo/transporter/certificate.pem`. It will then correct the ownership of the file and restart the Transporter.
  - Doesn't take any options, but the default file locations in the script can be modified.
  - Uses `cetcerts.sh`, for details see: https://github.com/dmgeurts/catcerts

## Automation

Examples of how to automate certificate renewals with ipa-getcert.

**Notes:**
- In these examples, it is assumed that the certificate CN is the hostname of the respective machine.
- You may prefer to put the scripts somewhere other than `/usr/local/bin/`.

### Director automation

Note that a Director by default is installed with a local Transporter.

```
sudo ipa-getcert request -K HTTP/$(hostname) \
    -k /etc/ssl/private/$(hostname).key -f /etc/ssl/certs/$(hostname).crt -D $(hostname) \
    -C "/usr/local/bin/director_chssl.sh -K $(hostname).crt && /usr/local/bin/transporter_chpem.sh"
```

### Transporter automation

```
sudo ipa-getcert request -K HTTP/$(hostname) \
    -k /etc/ssl/private/$(hostname).key -f /etc/ssl/certs/$(hostname).crt -D $(hostname) \
    -C "/usr/local/bin/transporter_chpem.sh"
```
