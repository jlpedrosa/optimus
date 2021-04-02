#!/bin/bash

export PASSWORD="topsecret"
export OPERATOR_IDENTITY="CN=NiFi poc,OU=Optimus,O=Test,C=ES"

export NODE0_SAN="SAN=dns:nifi-secure-0-0,dns:test.nifioperator.dev,dns:nifi-secure-0-0.nifi-secure-headless.default.svc.cluster.local"
export NODE0_IDENTITY="CN=nifi-secure-0-0"
export NODE1_SAN="SAN=dns:nifi-secure-1-0,dns:test.nifioperator.dev,dns:nifi-secure-1-0.nifi-secure-headless.default.svc.cluster.local"
export NODE1_IDENTITY="CN=nifi-secure-1-0"
export EXTERNAL_SERVER_IDENTITY="CN=ExternalServer"
export EXTERNAL_SAN="SAN=dns:nifi-docker,dns:localhost"

#Delete previous tests
rm *.jks 2> /dev/null
rm *.pem 2> /dev/null
rm *.crt 2> /dev/null
rm *.csr 2> /dev/null
rm *.p12 2> /dev/null
rm *.cer 2> /dev/null

#Generate key-pair and certs (unsigned) for all the players. CA1, CA2, NODE0, NODE1, Client1 and Client2.
keytool -genkey -keypass "$PASSWORD" -storepass "$PASSWORD" -storetype jks -validity 10000 -keyalg RSA -keysize 2048 -alias ca1 -ext bc:c -dname "CN=ca1"                 -keystore ca1.jks 
keytool -genkey -keypass "$PASSWORD" -storepass "$PASSWORD" -storetype jks -validity 10000 -keyalg RSA -keysize 2048 -alias ca2 -ext bc:c -dname "CN=ca2"                 -keystore ca2.jks
keytool -genkey -keypass "$PASSWORD" -storepass "$PASSWORD" -storetype jks -validity 10000 -keyalg RSA -keysize 2048 -alias certificate -dname "$NODE0_IDENTITY" -ext "$NODE0_SAN" -keystore node0.jks
keytool -genkey -keypass "$PASSWORD" -storepass "$PASSWORD" -storetype jks -validity 10000 -keyalg RSA -keysize 2048 -alias certificate -dname "$NODE1_IDENTITY" -ext "$NODE1_SAN" -keystore node1.jks
keytool -genkey -keypass "$PASSWORD" -storepass "$PASSWORD" -storetype jks -validity 10000 -keyalg RSA -keysize 2048 -alias certificate -dname "$OPERATOR_IDENTITY"  -keystore client1.jks 
keytool -genkey -keypass "$PASSWORD" -storepass "$PASSWORD" -storetype jks -validity 10000 -keyalg RSA -keysize 2048 -alias certificate -dname "$OPERATOR_IDENTITY"  -keystore client2.jks
keytool -genkey -keypass "$PASSWORD" -storepass "$PASSWORD" -storetype jks -validity 10000 -keyalg RSA -keysize 2048 -alias certificate -dname "$EXTERNAL_SERVER_IDENTITY"  -keystore externalserver.jks


## Node 0 
# Import CA1  into node1 keystore
keytool -export -alias ca1 -storepass "$PASSWORD" -keystore ca1.jks | keytool -import -noprompt -storepass "$PASSWORD" -keystore node0.jks -alias ca1
# Crete a certificate for node1 signed by ca1 and store it as cert in node1
keytool -certreq -keystore node0.jks -storepass "$PASSWORD" -alias certificate -ext "$NODE0_SAN" |\
keytool -gencert -keystore ca1.jks   -storepass "$PASSWORD" -alias ca1         -ext "$NODE0_SAN" |\
keytool -import  -keystore node0.jks -storepass "$PASSWORD" -alias certificate -trustcacerts -noprompt

## Node 1
# Import CA1  into node1 keystore
keytool -export -alias ca1 -storepass "$PASSWORD" -keystore ca1.jks | keytool -import -noprompt -storepass "$PASSWORD" -keystore node1.jks -alias ca1
# Crete a certificate for node1 signed by ca1 and store it as cert in node1
keytool -certreq -keystore node1.jks -storepass "$PASSWORD" -alias certificate -ext "$NODE1_SAN" |\
keytool -gencert -keystore ca1.jks   -storepass "$PASSWORD" -alias ca1         -ext "$NODE1_SAN" |\
keytool -import  -keystore node1.jks -storepass "$PASSWORD" -alias certificate -trustcacerts -noprompt 

## External server
# Import CA1  into external server keystore
keytool -export -alias ca1 -storepass "$PASSWORD" -keystore ca1.jks | keytool -import -noprompt -storepass "$PASSWORD" -keystore externalserver.jks -alias ca1
# Crete a certificate for node1 signed by ca1 and store it as cert in node1
keytool -certreq -keystore externalserver.jks -storepass "$PASSWORD" -alias certificate -ext "$EXTERNAL_SAN" |\
keytool -gencert -keystore ca1.jks   -storepass "$PASSWORD" -alias ca1         -ext "$EXTERNAL_SAN" |\
keytool -import  -keystore externalserver.jks -storepass "$PASSWORD" -alias certificate -trustcacerts -noprompt 



## Client1
# Import CA1 into client1 keystore
keytool -export -storepass "$PASSWORD" -keystore ca1.jks -alias ca1 | keytool -import -noprompt -storepass "$PASSWORD" -keystore client1.jks -alias ca1
# Create a certificate for the client with CA1
keytool -certreq -storepass "$PASSWORD" -alias certificate                         -keystore client1.jks |\
keytool -gencert -storepass "$PASSWORD" -alias ca1                                 -keystore ca1.jks     |\
keytool -import  -storepass "$PASSWORD" -alias certificate -trustcacerts -noprompt -keystore client1.jks

# Convert client1 store from jks to pkcs12 (so we can import it in chrome, wget...)
keytool -importkeystore -srckeystore client1.jks  -srcstorepass  "$PASSWORD" -srckeypass  "$PASSWORD" -srcalias certificate \
                        -destkeystore client1.p12 -deststorepass "$PASSWORD" -destkeypass "$PASSWORD" -destalias certificate -deststoretype PKCS12 

# Extract the CA1 In the pem format so we can add it as trusted ca in chrome, wget..
keytool -export  -storepass "$PASSWORD" -rfc -keystore ca1.jks -alias ca1 > ca1.crt


## Client2
# Import CA2 into client2 keystore
keytool -export -storepass "$PASSWORD" -keystore ca2.jks -alias ca2 | keytool -import -noprompt -storepass "$PASSWORD" -keystore client2.jks -alias ca2
# Create a certificate for the client with CA2
keytool -certreq -storepass "$PASSWORD" -alias certificate                         -keystore client2.jks |\
keytool -gencert -storepass "$PASSWORD" -alias ca2                                 -keystore ca2.jks     |\
keytool -import  -storepass "$PASSWORD" -alias certificate -trustcacerts -noprompt -keystore client2.jks

# Convert client2 store from jks to pkcs12 (so we can import it in chrome, wget...)
keytool -importkeystore -srckeystore client2.jks  -srcstorepass  "$PASSWORD" -srckeypass  "$PASSWORD" -srcalias certificate \
                        -destkeystore client2.p12 -deststorepass "$PASSWORD" -destkeypass "$PASSWORD" -destalias certificate -deststoretype PKCS12 


### truststore.jks
## Generate trust store with certs from CA1 and CA2 (For nodes truststore.jks)
keytool -export -alias ca1 -storepass "$PASSWORD" -keystore ca1.jks | keytool -import -noprompt -storepass "$PASSWORD" -keystore truststore.jks -alias ca1
keytool -export -alias ca2 -storepass "$PASSWORD" -keystore ca2.jks | keytool -import -noprompt -storepass "$PASSWORD" -keystore truststore.jks -alias ca2

