#!/bin/bash

set -u

source ./test_env.sh

## copy /etc/hosts to result folder and parse/output all nodes to .tmp/allnodes
rm -rf $OUTPUT_DIR; mkdir -p $OUTPUT_DIR
ssh $SSH_OPTION root@$ANY_NODE_IP "cd ${TEMPLATE_DIR}/.. && find $(basename ${TEMPLATE_DIR}) -type f" > ${OUTPUT_DIR}/allfiles
#scp $SSH_OPTION root@$ANY_NODE_IP:/etc/hosts $OUTPUT_DIR
cp /etc/hosts $OUTPUT_DIR

grep -v $(hostname) ${OUTPUT_DIR}/hosts > ${OUTPUT_DIR}/hosts2

#sed "s/127.255.255.1/${ANY_NODE_IP}/g" "${OUTPUT_DIR}/hosts"                  #this work on linux
#sed -i "" "/$ANY_NODE/ s/.*/$ANY_NODE_IP    $ANY_NODE/g" "${OUTPUT_DIR}/hosts" #this work on mac
#echo -e ${ANY_NODE_IP} ${ANY_NODE} > $ALL_NODES_FILE

NeucaItems='n'
while IFS= read -r line
do
    begin=$(cut -d' ' -f 1 <<< $line)
    if [ "$NeucaItems" == "n" ] && [ "$begin" == "###" ] && [ -z "${line##*comet*}" ]; then
      NeucaItems='y'
    fi
    if [ "$NeucaItems" == "y" ] && [ "$begin" != "###" ] && [ "$line" != "" ] && [ -z "${line##*'.'*}" ]; then
        echo $line >> $ALL_NODES_FILE
    fi
done < "${OUTPUT_DIR}/hosts2"

## get the interfaces and gw information from all nodes
while IFS= read -r line; do
    nodeip=$(echo $line | awk '{print $1;}'); #echo $nodeip
    node=$(echo $line | awk '{print $2;}'); #echo $node
    scp $SSH_OPTION root@${nodeip}:/root/tmp_links.sh ${OUTPUT_DIR}/${node}_links.sh
    scp $SSH_OPTION root@${nodeip}:/root/tmp_gw ${OUTPUT_DIR}/${node}_gw
    scp $SSH_OPTION test_env.sh root@${nodeip}:test_env.sh
    scp $SSH_OPTION src_create_data.sh root@${nodeip}:src_create_data.sh
    scp $SSH_OPTION dest_transfer_diff.sh root@${nodeip}:dest_transfer_diff.sh
    scp $SSH_OPTION ../../storage/cj_corrupt.py root@${nodeip}:chaos-jungle/storage/
    #ssh -n $SSH_OPTION root@${nodeip} "sudo chmod u+x /root/dest_transfer_diff.sh"
    if [ -f "${OUTPUT_DIR}/${node}_gw" ]; then
        router=$(cut -d':' -f 2 <<< $(less ${OUTPUT_DIR}/${node}_gw))
        echo $node is end node, gw IP:$router
        if [ "$router" != "" ]; then
            echo $line >> $END_NODES_FILE
        fi
    fi
    cat ${OUTPUT_DIR}/${node}_links.sh >> $ALL_EDGES_FILE
done < $ALL_NODES_FILE

cp $END_NODES_FILE $SRC_NODES_FILE
cp $END_NODES_FILE $DEST_NODES_FILE
cp $END_NODES_FILE $CORRUPT_NODES_FILE
cp $ALL_EDGES_FILE $CORRUPT_EDGES_FILE

set -u
source ./include.sh
_generate_node_router_file # generate node_router.txt


# Configure firewall for apache2 web server on END_NODES
#_get_end_nodes
#echo $END_NODES
#for nodeip in $END_NODES; do
    #SSH_DEST=${USER}@${nodeip}
    #echo $SSH_DEST
    #ssh $SSH_OPTION $SSH_DEST sudo ufw allow from $SUBNET
    #ssh $SSH_OPTION $SSH_DEST sudo ufw allow from $CONTROL_NODE
#done

