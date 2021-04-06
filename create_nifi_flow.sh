#!/bin/bash

#sendPost sends a post HTTP request to NIFI, 
#First argument is the relative #url of the controller (wihtout prepending the slash), 
#Second argument is the body to send
function sendPost() {
  URL="$1" 
  BODY="$2"
  curl "http://$NIFI_IP/nifi-api/$URL" \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'Content-Type: application/json' \
  -H "Origin: http://$NIFI_IP" \
  -H "Referer: http://$NIFI_IP/nifi/" \
  --data-raw "$BODY" \
  --insecure \
  --no-progress-meter
}

#sendPut sends a put HTTP request to NIFI, 
#First argument is the relative #url of the controller (wihtout prepending the slash), 
#Second argument is the body to send
function sendPut() {
  URL="$1" 
  BODY="$2"
  curl "http://$NIFI_IP/nifi-api/$URL" \
  -X 'PUT' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'Content-Type: application/json' \
  -H "Origin: http://$NIFI_IP" \
  -H "Referer: http://$NIFI_IP/nifi/" \
  --data-raw "$BODY" \
  --insecure \
  --no-progress-meter
}

#sendGet sends a get request to the NiFi API
#First argument is the relative url of the controller (wihtout prepending the slash)
function sendGet() {
  URL="$1"
  curl "http://$NIFI_IP/nifi-api/$URL" \
  -H 'Connection: keep-alive' \
  -H 'Accept: */*' \
  --insecure \
  --no-progress-meter
}

# parseJSONAndUpdateClientId reads a json file inside of the local folder nifi_workflow_steps
# and replaces the client id in the request with the one provided in the second argument
function parseJSONAndUpdateClientId() {
    FILE="$1"
    CLI_ID="$2"
    DEFINITION_PATH="./nifi_workflow_steps/$FILE"    
    cat $DEFINITION_PATH | jq ".revision.clientId = \"$CLI_ID\" | .revision.version = 0"
}

#createFlowFromFile creates a flow in nifi, 
#based on the file provided as first argument and the client Id prvided in the second
function createFlowFromFile() {
    FILE="$1"
    CLI_ID="$2"

    BODY=$(parseJSONAndUpdateClientId $FILE $CLI_ID)  
    REPLY=$(sendPost "process-groups/root/processors" "$BODY")
    if [ ! $( echo "$REPLY" | jq -r '.id') ]; then
      echo "ERR: $REPLY" >> logme
      exit -1;
    fi
    echo "OK: $REPLY" >> logme
    echo $REPLY | jq -r '.id'
}

# Connects two processors
function connectComponents() {
  CLI_ID="$1"
  ROOT_NODE="$2"
  SRC_COMPONENT="$3"
  DST_COMPONENT="$4"
  SUCC_FAILURE="$5"

  #Read the default connection updating the clientId
  BODY=$(parseJSONAndUpdateClientId connection.json $CLI_ID)

  #Update the group Id for source and destination, as well as the ID components  
  CONNECTION=$(echo "$BODY" |\
  jq ".component.source.groupId = \"$ROOT_NODE\" | .component.destination.groupId = \"$ROOT_NODE\"" |\
  jq ".component.source.id = \"$SRC_COMPONENT\" | .component.destination.id = \"$DST_COMPONENT\"" |\
  jq ".component.selectedRelationships[0] = \"$SUCC_FAILURE\"")   
  
  sendPost "process-groups/root/connections" "$CONNECTION"
}

function getComponent() {
  COMPONENT_ID="$1"
  sendGet "processors/$COMPONENT_ID"
}

function startComponent() {
  CLIENT_ID="$1"  
  COMPONENT_ID="$2"
  
  #Form URL
  REQUEST_URL="processors/$COMPONENT_ID/run-status"

  #Form body
  COMPONENT_JSON=$(getComponent "$COMPONENT_ID") 
  COMPONENT_VERSION=$(echo $COMPONENT_JSON | jq '.revision.version')  
  
  #Create the request whith the right client ID and version
  REQUEST='{"revision":{"clientId":"91ee7a97-0177-1000-fa1a-d5f60fb733b0","version":2},"state":"RUNNING","disconnectedNodeAcknowledged":false}'
  REQUEST=$(echo "$REQUEST" | jq ".revision.clientId = \"$CLIENT_ID\" | .revision.version = \"$COMPONENT_VERSION\" ")

  sendPut "$REQUEST_URL" "$REQUEST"
}

NIFI_IP="$1"
echo "Starting to provision sample flow to NiFi at: $NIFI_IP"

CLIENT_ID=$(sendGet flow/client-id)
echo "CLIENT_ID: $CLIENT_ID"

ROOT_PG_ID=$(sendGet "process-groups/root" | jq -r '.id' | tr -d "\n")
echo "ROOT_PG_ID: $ROOT_PG_ID"

echo "Creating processors..."
LOADGEN_ID=$(createFlowFromFile "01-GenerateFlowFile.json" "$CLIENT_ID")
COMPRESS_CONTENT_ID=$(createFlowFromFile "02-CompressContent.json" "$CLIENT_ID")
ATTR_FAILURE_ID=$(createFlowFromFile "03-UpdateAttrFailures.json" "$CLIENT_ID")
ATTR_SUCESS_ID=$(createFlowFromFile "04-UpdatAttrSuccess.json" "$CLIENT_ID")

echo "Connecting processors..."
CONNECTION_LOADGEN_COMPRESS=$(connectComponents "$CLIENT_ID" "$ROOT_PG_ID" "$LOADGEN_ID" "$COMPRESS_CONTENT_ID" "success")
CONNECTION_COMPRESS_SUCCESS=$(connectComponents "$CLIENT_ID" "$ROOT_PG_ID" "$COMPRESS_CONTENT_ID" "$ATTR_SUCESS_ID" "success")
CONNECTION_COMPRESS_FAILURE=$(connectComponents "$CLIENT_ID" "$ROOT_PG_ID" "$COMPRESS_CONTENT_ID" "$ATTR_FAILURE_ID" "failure")

echo "Starting processors..."
discard=$(startComponent "$CLIENT_ID" "$ATTR_SUCESS_ID")
discard=$(startComponent "$CLIENT_ID" "$ATTR_FAILURE_ID")
discard=$(startComponent "$CLIENT_ID" "$LOADGEN_ID" )
discard=$(startComponent "$CLIENT_ID" "$COMPRESS_CONTENT_ID")

exit 0
