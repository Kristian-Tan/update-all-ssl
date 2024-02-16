#!/bin/bash -

# read config.txt, then remove empty lines or comment lines
cat config.txt | sed 's/#.*$//' | awk 'NF' | while read -r LINE; do

  # parse each line, explode/split by spasi/tab
  LINE=$(echo "$LINE" | tr "\t" ' ' | tr -s ' ')
  CERTDIR=$(echo "$LINE" | cut -d' ' -f1)
  SOCKET=$(echo "$LINE" | cut -d' ' -f2)
  SSHCMD=$(echo "$LINE" | cut -d' ' -f3-)

  # cd to CERTDIR, then compare certificate.crt against ssl in production socket (e.g.: tcp socket port 443 for https)
  cd "$CERTDIR"
  FINGERPRINT_CERT=$(openssl x509 -fingerprint -noout -in "$CERTDIR"/certificate.crt)
  FINGERPRINT_SERVER=$(openssl s_client -connect "$SOCKET" < /dev/null 2>/dev/null | openssl x509 -fingerprint -noout -in /dev/stdin)

  # if the fingerprint is not identical, then run command to update ssl
  if [[ "$FINGERPRINT_CERT" != "$FINGERPRINT_SERVER" ]]; then
    echo "certificate in $SOCKET outdated, updating..."
    #tar -czvf /dev/stdout . | $SSHCMD
    rm -f /tmp/ssl.tar.gz
    tar -czvf /tmp/ssl.tar.gz .
    chmod 0600 /tmp/ssl.tar.gz
    # file /tmp/ssl.tar.gz
    # md5sum /tmp/ssl.tar.gz
    cat /tmp/ssl.tar.gz | $SSHCMD
    rm -f /tmp/ssl.tar.gz
  else
    echo "certificate in $SOCKET is latest version, no update needed"
  fi
done
