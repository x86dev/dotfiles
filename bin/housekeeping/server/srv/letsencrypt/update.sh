#!/bin/sh

# Uses https://github.com/lukas2511/dehydrated
MY_PATH_LETSENCRYPT=/srv/letsencrypt

# Note: ${MY_PATH_LETSENCRYPT}/domains.txt *must* contain the domains
#       as well -- one domain per line.
MY_CA_CERTS="subdomain.example.com subdomain2.example2.org"

MY_PATH_SCRIPT=${MY_PATH_LETSENCRYPT}/script
MY_PATH_ACME_CHALLENGE=${MY_PATH_LETSENCRYPT}/acme-challenge
MY_PATH_CERTS=${MY_PATH_LETSENCRYPT}/certs

mkdir -p ${MY_PATH_ACME_CHALLENGE}
mkdir -p ${MY_PATH_CERTS}

cd ${MY_PATH_SCRIPT}
# git pull
chmod u=rwX,go=rX -R ${MY_PATH_ACME_CHALLENGE}/.well-known
./dehydrated.sh --cron --config ${MY_PATH_LETSENCRYPT}/letsencrypt.conf

echo "Installing certificates ..."
for CUR_CERT in $MY_CA_CERTS
do
	cp ${MY_PATH_CERTS}/${CUR_CERT}/fullchain.pem ${MY_PATH_CERTS}/${CUR_CERT}.crt
	cp ${MY_PATH_CERTS}/${CUR_CERT}/privkey.pem ${MY_PATH_CERTS}/${CUR_CERT}.key

	# Generate own Diffie-Hellman Groups per cert.
	openssl dhparam -out ${MY_PATH_CERTS}/${CUR_CERT}.dhparam.pem 4096
done
chmod 600 -R ${MY_PATH_CERTS}

echo "Done. Note: The web server needs to be restarted in order to fetch the new certificates!"
