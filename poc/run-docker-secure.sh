#!/bin/sh

CERT_PATTHS="cert-paths"
CONF_OVERRIDE_PATH="nifi folder with conf"
INITIAL_ADMIN_ID="SAME CN=.... as in tls-generationscript"
docker run --name nifi-docker \
  -v "$CERT_PATTHS":/opt/certs \
  -v "$CONF_OVERRIDE_PATH":/opt/nifi/nifi-current/conf \
  -p 8443:8443 \
  -e AUTH=tls \
  -e KEYSTORE_PATH=/opt/certs/externalserver.jks \
  -e KEYSTORE_TYPE=JKS \
  -e KEYSTORE_PASSWORD=topsecret \
  -e TRUSTSTORE_PATH=/opt/certs/truststore.jks \
  -e TRUSTSTORE_PASSWORD=topsecret \
  -e TRUSTSTORE_TYPE=JKS \
  -e INITIAL_ADMIN_IDENTITY="$INITIAL_ADMIN_ID" \
  -e NODE_IDENTITY="CN=nifi-secure-0" \
  --rm \
   apache/nifi:1.12.1