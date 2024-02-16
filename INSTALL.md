# Custom Shell for Each Server Specific Installation

- copy file `update-all-ssl.sh` to central server, create `config.txt` file (optionally, add it to crontab) 
- on each server, do steps below:
- list where the ssl certificate files are loaded from (assuming apache2)

```bash
grep -h 'SSLCertificate' /etc/apache2/sites-enabled/* | grep -v '#' | tr -s ' ' | sort | uniq
```

- create custom shell for user "ssl-manager", which read STDIN and extract it as tar.gz then copy to apache ssl directory

```bash
cat > /opt/ssl-update-shell <<"END"
#!/bin/bash -

# copy content of stdin (should contain .tar.gz file) to /tmp/stdin.tar.gz
cat <&0 >/tmp/stdin.tar.gz

# extract inside a directory
mkdir temp_extract
cd temp_extract
tar -xzvf /tmp/stdin.tar.gz >/dev/null 2>/dev/null

# show content of the gzipped stdin for debug purpose
ls -R

# run custom command specific for this server only
# (e.g.: copy the certificate/key/chain to a specific directory, restart webserver)
sudo /etc/ssl-update-shell

# cleanup: delete the temporary directory and the temp .tar.gz for stdin
cd ..
rm -r temp_extract
rm /tmp/stdin.tar.gz
END
```

- create etc (editable text config) for each server (may be modified to fit each server's need, e.g.: server A use apache2 as webserver while server B use nginx therefore cert path differs, or server A use systemd while server B use sysvinit therefore the reload command differs)

```bash
cat > /etc/ssl-update-shell <<"END"
#!/bin/bash -

BACKUPDIR=/etc/apache2/ssl/backup-$(date +'%Y-%m-%d-%H-%M-%S')/

# these lines are server specific
CERT_PATH=/etc/apache2/ssl/certificate.crt
KEY_PATH=/etc/apache2/ssl/private.key
CHAIN_PATH=/etc/apache2/ssl/comodo_bundle.crt
RELOAD='systemctl restart apache2'

if [ ! -f certificate.crt ]; then
  echo "certificate.crt not found!"
  exit 1
fi

if [ ! -f private.key ]; then
  echo "private.key not found!"
  exit 1
fi

if [ ! -f chain.crt ]; then
  echo "chain.crt not found!"
  exit 1
fi

mkdir "$BACKUPDIR"
cp "$CERT_PATH" "$BACKUPDIR"
cp "$KEY_PATH" "$BACKUPDIR"
cp "$CHAIN_PATH" "$BACKUPDIR"

rm "$CERT_PATH"
rm "$KEY_PATH"
rm "$CHAIN_PATH"

cp certificate.crt "$CERT_PATH"
cp private.key "$KEY_PATH"
cp chain.crt "$CHAIN_PATH"

chown root:root "$CERT_PATH"
chmod 0600 "$CERT_PATH"
chown root:root "$KEY_PATH"
chmod 0600 "$KEY_PATH"
chown root:root "$CHAIN_PATH"
chmod 0600 "$CHAIN_PATH"

$RELOAD
END
```

- chmod to allow execute the custom shell and the etc, then create ssl-manager user, and set its ssh key, then add /etc/ssl-update-shell to be executable with sudo for ssl-manager user

```bash
chmod 0755 /opt/ssl-update-shell
chmod 0755 /etc/ssl-update-shell

grep 'ssl-manager' /etc/passwd || useradd -s /opt/ssl-update-shell -m -d /home/ssl-manager -k /etc/skel ssl-manager

mkdir -p /home/ssl-manager/.ssh/

cat > /home/ssl-manager/.ssh/authorized_keys <<"END"
ssh-rsa YOUR-SSH-KEY-HERE
END

chmod -R 0700 /home/ssl-manager/.ssh/
chown -R ssl-manager:ssl-manager /home/ssl-manager/.ssh/

grep 'ssl-manager' /etc/sudoers || `echo 'ssl-manager ALL=(ALL) NOPASSWD: /etc/ssl-update-shell' >> /etc/sudoers`

```
