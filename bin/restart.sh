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

STACK_NAME=$(curl -s --fail rancher-metadata/2015-12-19/self/stack/name)
RET=$?
if [ $RET -ne 0 ]; then
        echo "Failed to get own stack name"
        exit 1
fi
echo Stack name: $STACK_NAME

CONTAINER_NAME=$(curl -s --fail rancher-metadata/2015-12-19/self/container/name)
RET=$?
if [ $RET -ne 0 ]; then
        echo "Failed to get own container name"
        exit 1
fi
echo Container name: $CONTAINER_NAME

INDEX=-1
export IFS="_"
for element in $CONTAINER_NAME; do
        INDEX="$element"
done

export IFS=" "
echo Index: $INDEX

HAZELCAST_NODE_HOSTNAME="${STACK_NAME}_hazelcast-conf_hazelcast-node_${INDEX}"
echo Hazelcast host : $HAZELCAST_NODE_HOSTNAME

echo Contacting Supervisord on ${HAZELCAST_NODE_HOSTNAME} via XML/RPC API to restart hazelcast process
echo Stopping process hazelcast-server...
RESP=$(echo '<?xml version="1.0"?><methodCall><methodName>supervisor.stopProcess</methodName><params><param><value><string>hazelcast-server</string></value></param><param><value><string>true</string></value></param></params></methodCall>' | curl -d @- http://hazelcast_hazelcast-conf_hazelcast-node_1:9001/RPC2)
if [ $RET -ne 0 ]; then
	

fi


echo '<?xml version="1.0"?><methodCall><methodName>supervisor.startProcess</methodName><params><param><value><string>hazelcast-server</string></value></param><param><value><string>true</string></value></param></params></methodCall>' | curl -d @- http://hazelcast_hazelcast-conf_hazelcast-node_1:9001/RPC2

