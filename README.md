# SSL Manager

### Task
auto renew SSL certificate from 1 centralized server

### Reference
- get ssl fingerprint from a certificate file:
	- cmd:
		`openssl x509 -fingerprint -in certificate.crt -noout`
	- output:
		`SHA1 Fingerprint=A9:E4:79:6F:84:55:2E:C3:18:87:C3:C8:74:D7:4B:78:3B:11:66:C2`
- get ssl fingerprint from a socket:
	- cmd:
		`openssl s_client -connect my.domain.com:443 < /dev/null 2>/dev/null | openssl x509 -fingerprint -noout -in /dev/stdin`
	- output:
		`SHA1 Fingerprint=A9:E4:79:6F:84:55:2E:C3:18:87:C3:C8:74:D7:4B:78:3B:11:66:C2`
- plan:
	- create a new user on each server, (default name: `ssl-manager`), and set its default shell to our shell, example entry in `/etc/passwd`:
		`ssl-manager:x:1022:1024:,,,:/home/ssl-manager:/opt/ssl-update-shell`
	- the custom shell must read tar.gz from stdin and extract its content, which contain private key, ssl certificate, and chain certificate/trust/CA certificate
	- the custom shell can be allowed to run a custom sudo command if needed to restart apache2 or copy ssl files (private key, ssl certificate, chain certificate) to /etc/apache2/ssl or /etc/ssl/
	- to prevent remote command execution vulnerability, the custom shell must not execute command that is passed via argument (e.g.: `$1` or `$@`)
	- authenticating ssh from centralized server to each server must not use password (ssh key usage is recommended instead)
- example content of config.txt:
	```
	# <certdir>					<host:port>				<ssh-cmd>
	/home/kristian/STAR_CERT/	my.domain.com:443		ssh ssl-manager@my.domain.com
	# directory <certdir> must contain these files: certificate.crt chain.crt private.key
	```

### Use Case
- you have a lot of servers that served content over https (or any other ssl enabled socket like smtp)
- you have 1 central server that hold ssl certificate files (consist of certificate.crt, private.key, and chain.crt)
- the certificate.crt and chain.crt must be updated every year (or every ... interval of time) because the certificate expires
- updating those certificate files must be done one by one everytime such update need to be executed
- this script automates the copying, and provide additional feature/security:
	- you don't need to scp as root (this script can be used even if you disable ssh login as root)
	- ssl directory on each server is configured inside each server's config files, so when configuring the central server, you don't have to know where it is
	- if fingerprint of certificate file in central server is already identical with fingerprint in socket's certificate, no actual copying happens, so this script is safe to be executed frequently  (e.g.: each hour by cron)
	- even if the central server is compromised, each other server is not compromised because the ssh login is to a custom shell that only can do specific task (no remote code execution vulnerability); so the worst thing that can happen if central server is compromised is exposure of your ssl private key and all your services might use improper certificate (or failed to start)
