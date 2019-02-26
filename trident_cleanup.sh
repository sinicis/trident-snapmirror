# DEFINITIONS
LOGFILE=__LOG_FILE__

# log function
log(){
	typ=$1
	msg=$2
	if [ "${typ}" == "ERROR" ]; then
		echo "$(date +%F" "%R:%S) ${typ} ${msg}" | tee -a ${LOGFILE}
	elif [ "${typ}" == "INFO" ]; then
		echo "$(date +%F" "%R:%S) ${typ}  ${msg}" >> ${LOGFILE}
	fi
}

# check k8s availabilty
netcat -zw1 __KUBE_API_URL__ 443
if [ $? -ne 0 ]; then
	log "ERROR" "k8s-api is not reachable on port 443"
	exit
fi

# check k8s login credentials
kubectl get nodes 2>&1 | grep -q "was refused"
if [ $? -eq 0 ]; then
	log "ERROR" "user __SCRIPT_EXECUTOR__ is not logged in and cannot make any k8s-api calls"
	exit 1
fi

# check svm ssh-connection
ssh tridentsvm exit > /dev/null 2>&1
if [ $? -ne 0 ]; then
	log "ERROR" "user '__SCRIPT_EXECUTOR__' cannot craete a SSH connection to the SVM over SSH Alias 'tridentsvm' - check __DEST_OF_SSH_CONFIG__"
	exit 1
fi

# check trident pod
kubectl get pod --namespace trident | grep "^trident-" | grep "2/2" | egrep "Running|Ready" > /dev/null 2>&1
if [ $? -ne 0 ]; then
	log "ERROR" "Trident pod does not exist, is not ready or running"
	exit 1
fi

# check log availability
for VOLUME in $(kubectl logs --namespace trident $(kubectl get pods --namespace trident --output name) --container trident-main --since=72h | grep "Kubernetes frontend failed to delete the volume for PV.*is the source endpoint of one or more SnapMirror relationships" | cut -d "\\" -f2 | tr -d "\"" | sort | uniq); do

	ssh -n tridentsvm "vol show -volume ${VOLUME}" > /dev/null 2>&1
	# exit code 255 --> volume is deleted
	if [ $? -eq 0 ]; then
		SM_DEST=$(ssh -n tridentsvm "snapmirror list-destinations -source-volume ${VOLUME} -fields destination-path" | awk "/^.*:${VOLUME}/{print \$2}" | sed "s/[[:space:]]*\r\?//g")
		if [ "${SM_DEST}" != "" ]; then
			ssh -n tridentsvm "snapmirror release -destination-path ${SM_DEST}" > /dev/null 2>&1 
			if [ $? -ne 0 ]; then 
				log "ERROR" "Snapmirror Destination '${SM_DEST}' could not be released from volume '${VOLUME}'"
			else
				log "INFO" "Snapmirror Destination '${SM_DEST}' succesfully released from volume '${VOLUME}'"
			fi
		fi 
	fi
done

# check permissions of LOGFILE
chmod 640 ${LOGFILE}
