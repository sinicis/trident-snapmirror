Trident: Snapmirror relations
=============================

## Purpose
This is an addition to run [Trident Storage Provisioner](https://github.com/netapp/trident) in a productive environment with snap mirror relations.

Trident does not provide a feature to automatically create snapmirror relations. This has to be solved about some automation (scheduled task) on the ONTAPI side which brings disadvantages: Trident cannot delete a PV because an existing snapmirror relation which cannot be released:
```bash
time="2019-02-26T09:36:29Z" level=error msg="Kubernetes frontend failed to delete the volume for PV __PV_NAME__: error destroying volume __VOLUME_NAME__: API status: failed, Reason: Volume \"__VOLUME__NAME__\" in Vserver \"__SVM__\" is the source endpoint of one or more SnapMirror relationships. Before you delete the volume, you must release the source information of the SnapMirror relationships using \"snapmirror release\". To display the destinations to be used in the \"snapmirror release\" commands, use the \"snapmirror list-destinations -source-vserver __SVM__ -source-volume __VOLUME_NAME__\" command., Code: 18436. Will eventually retry, but volume and PV may need to be manually deleted."
```

The approach of my script is to check the logs of the trident pod, find these log entries, connect to svm and release the snapmirror relation. Trident itself will always retry failed tasks. Means the deletion of the volume does not be done within the script.

### Supported versions and platforms
Currently the script only supports k8s. I'm glad for any OpenShift addition.

It is tested with Trident 18.07

## Pre-requisites
There are several pre-requisites:
* running k8s cluster
* provisioned and working trident
* automated jobs on ONTAPI to create snapmirror relations
* generated keypair (vsadmin user has the pubkey configured on SVM)
* script-executor has a [ssh config](examples/ssh_config)
* script-executor has k8s permissions to read trident logs

## Script
The script is written in Bash so there is no extra tooling.

It contains several placeholder which have to be substituded to run the script properly:
* `__KUBE_API_URL__` no explanation needed
* `__LOG_FILE__` destination of your log file for debugging
* `__SCRIPT_EXECUTOR__` only for debugging reasons (could be substituted which `$(whoami)`)
* `__DEST_OF_SSH_CONFIG__` only for debugging reasons (can be removed)
