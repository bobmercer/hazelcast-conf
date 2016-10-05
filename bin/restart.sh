#!/bin/bash
echo Discovering sidekick hazelcast node instance for the current container

# Wait for metadata service to be available
iter=0
while :; do
        if [ $iter -gt 9 ]; then
                echo ERROR: Cannot contact rancher-metadata service
                exit 1
        fi
        curl -s --fail rancher-metadata >/dev/null
        if [ $? -eq 0 ]; then
                break
        fi
        iter=$((iter+1))
        sleep 1
done

# DNS entry for hazelcast node is like <stack_name>_hazelcast-conf_hazelcast-node_<index>
# Check Stack name (usefull for Sidekick DNS entry)
STACK_NAME=$(curl -s --fail rancher-metadata/2015-12-19/self/stack/name)
RET=$?
if [ $RET -ne 0 ]; then
        echo "Failed to get own stack name"
        exit 1
fi
echo Stack name: $STACK_NAME
# Check Container name (usefull for Sidekick DNS entry)
CONTAINER_NAME=$(curl -s --fail rancher-metadata/2015-12-19/self/container/name)
RET=$?
if [ $RET -ne 0 ]; then
        echo "Failed to get own container name"
        exit 1
fi
echo Container name: $CONTAINER_NAME
# Check index based on container_name
INDEX=-1
export IFS="_" # Delimiter = _
for element in $CONTAINER_NAME; do
        INDEX="$element"
done

export IFS=" " # Reinitialize
echo Index: $INDEX

HAZELCAST_NODE_HOSTNAME="${STACK_NAME}_hazelcast-conf_hazelcast-node_${INDEX}"
echo Hazelcast host : $HAZELCAST_NODE_HOSTNAME

echo Check if hazelcast node is already started
/bin/bash wait-for-it.sh $HAZELCAST_NODE_HOSTNAME:5701 -t 0 --strict -- echo "Hazelcast node is up" 

echo Contacting Supervisord on ${HAZELCAST_NODE_HOSTNAME} via XML/RPC API to restart hazelcast process
echo Stopping process hazelcast-server...
RESP=$(echo '<?xml version="1.0"?><methodCall><methodName>supervisor.stopProcess</methodName><params><param><value><string>hazelcast-server</string></value></param><param><value><string>true</string></value></param></params></methodCall>' | curl -s --fail -d @- http://hazelcast_hazelcast-conf_hazelcast-node_1:9001/RPC2)
RET=$?
if [ $RET -ne 0 ]; then
	echo "Failed to contact Supervisor XML/RPC API to stop hazelcast-server process" 
	exit 1
else
	# Check if response is correct
	XML_CODE=$(xmllint --xpath "//methodResponse/params/param/value/boolean/text()" - <<<$RESP)
	if [[ $XML_CODE == "1" ]]; then
		echo Process hazelcast-server successfully stopped
		RESP=$(echo '<?xml version="1.0"?><methodCall><methodName>supervisor.startProcess</methodName><params><param><value><string>hazelcast-server</string></value></param><param><value><string>true</string></value></param></params></methodCall>' | curl -s --fail -d @- http://hazelcast_hazelcast-conf_hazelcast-node_1:9001/RPC2)
		RET=$?
		if [ $RET -ne 0 ]; then
			echo "Failed to contact Supervisor XML/RPC API to start hazelcast-server process" 
			exit 1
		fi
		XML_CODE=$(xmllint --xpath "//methodResponse/params/param/value/boolean/text()" - <<<$RESP)
		if [[ $XML_CODE == "1" ]]; then
			echo Process hazelcast-server successfully started
		else
			echo Supervisor error : $RESP
		fi
	else
		echo Supervisor error : $RESP
	fi
fi
