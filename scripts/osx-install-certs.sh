#!/bin/bash
# Download and install certs to the Mac OS X Keychain and update
# the CA_BUNDLE environment variables in your profile (if not already set within)

build_path=/tmp/domain_certs
rm -rf "${build_path}"
mkdir -p "${build_path}"

pushd "${build_path}"
curl -s -S -f \
-O http://crl.domain.local/pki/Root%20CA2.pem \
-O http://crl.domain.local/pki/ProdCACertBundle.pem \
-O http://crlstage.domain.local/pki/TestCACertBundle.pem \
-O http://crlstage.domain.local/pki/DevCACertBundle.pem \
-O http://crl.domain.local/pki/Policy%20CA2%20Int1.pem \
-O http://crl.domain.local/pki/Policy%20CA2%20Ext1.pem \
-O http://crl.domain.local/pki/OutboundInternet.pem \
-O http://crl.domain.local/pki/OutboundInternetNext.pem \
-O http://crl.domain.local/pki/Issuing%20CA2%20Cloud%201.pem \
-O http://crl.domain.local/pki/Issuing%20CA2%20SSL%20Code%20Signing%201.pem \
-O http://crlstage.domain.local/pki/Test%20Root%20CA2.pem \
-O http://crlstage.domain.local/pki/Test%20Policy%20CA2%20Int1.pem \
-O http://crlstage.domain.local/pki/Test%20Policy%20CA2%20Ext1.pem \
-O http://crlstage.domain.local/pki/Test%20Issuing%20CA2%20Cloud%201.pem \
-O http://crlstage.domain.local/pki/Test%20Issuing%20CA2%20SSL%20Code%20Signing%201.pem \
-O http://crlstage.domain.local/pki/Dev%20Root%20CA2.pem \
-O http://crlstage.domain.local/pki/Dev%20Policy%20CA2%20Int1.pem \
-O http://crlstage.domain.local/pki/Dev%20Policy%20CA2%20Ext1.pem \
-O http://crlstage.domain.local/pki/Dev%20Issuing%20CA2%20Cloud%201.pem \
-O http://crlstage.domain.local/pki/Dev%20Issuing%20CA2%20SSL%20Code%20Signing%201.pem
popd


for cert in $build_path/*.*; do
  [ -e "$cert" ] || continue
  basefilename=$(basename "${cert}")
  echo "Processing Cert File: ${cert}"
  echo "Cert File: ${basefilename}"

  sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain "${cert}"
done

CA_CERT=/etc/ssl/certs/ca-certificates.crt  
TMP_CA_CERT=/tmp/nm_certs/ca-certificates.crt

sudo mkdir -p /etc/ssl/certs
sudo touch $CA_CERT

security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > $TMP_CA_CERT
security find-certificate -a -p /Library/Keychains/System.keychain >> $TMP_CA_CERT

sudo cp -f $TMP_CA_CERT $CA_CERT

if [ "$SHELL" = "/bin/bash" ]; then
  echo "Adding variable to shell profiles to bash profile"
  if ! grep -q "CA_BUNDLE" "$HOME"/.bash_profile; then
    echo "Adding CA_BUNDLE to $HOME/.bash_profile"
    echo "export CA_BUNDLE="${CA_CERT}"" >> "$HOME"/.bash_profile
  fi
  if ! grep -q "REQUESTS_CA_BUNDLE" "$HOME"/.bash_profile; then
    echo "Adding REQUESTS_CA_BUNDLE to $HOME/.bash_profile"
    echo "export REQUESTS_CA_BUNDLE="${CA_CERT}"" >> "$HOME"/.bash_profile
  fi
  if ! grep -q "HTTPLIB2_CA_CERTS" "$HOME"/.bash_profile; then
    echo "Adding HTTPLIB2_CA_CERTS to $HOME/.bash_profile"
    echo "export HTTPLIB2_CA_CERTS="${CA_CERT}"" >> "$HOME"/.bash_profile
  fi
fi
if [ "$SHELL" = "/bin/zsh" ]; then
  echo "Adding variable to shell profiles to zsh profile"
  if ! grep -q "CA_BUNDLE" "$HOME"/.zshrc; then
    echo "Adding CA_BUNDLE to $HOME/.zshrc"
    echo "export CA_BUNDLE="${CA_CERT}"" >> "$HOME"/.zshrc
  fi
  if ! grep -q "REQUESTS_CA_BUNDLE" "$HOME"/.zshrc; then
    echo "Adding REQUESTS_CA_BUNDLE to $HOME/.zshrc"
    echo "export REQUESTS_CA_BUNDLE="${CA_CERT}"" >> "$HOME"/.zshrc
  fi
  if ! grep -q "HTTPLIB2_CA_CERTS" "$HOME"/.zshrc; then
    echo "Adding HTTPLIB2_CA_CERTS to $HOME/.zshrc"
    echo "export HTTPLIB2_CA_CERTS="${CA_CERT}"" >> "$HOME"/.zshrc
  fi
  if ! grep -q "OPENSSL_CONF" "$HOME"/.zshrc; then
    echo "Adding OPENSSL_CONF to $HOME/.zshrc"
    echo "export OPENSSL_CONF=/usr/local/etc/openssl@3/openssl.cnf" >> "$HOME"/.zshrc
  fi
  if ! grep -q "NODE_EXTRA_CA_CERTS" "$HOME"/.zshrc; then
    echo "Adding NODE_EXTRA_CA_CERTS to $HOME/.zshrc"
    echo "export NODE_EXTRA_CA_CERTS="${CA_CERT}"" >> "$HOME"/.zshrc
  fi
fi
