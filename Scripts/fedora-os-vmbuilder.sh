#!/bin/bash

# January 2024
# From: https://github.com/francismunch/vmbuilder/blob/main/vmbuilder.sh
# 
# This script will create a VM 
# Hardcoded to use fedora-coreos-39.20231204.3.3-live.x86_64.iso. This is my use case/requirment. Modify as deemed
#
# When the VM is booted for the first time, it will boot from the ISO as there is no OS on the hard disk
# subsequent boots will boot from the hard disk

# Proxmox 8.1.3

echo
while true; do
   read -r -p "Enter desired hostname for the Virutal Machine: " NEWHOSTNAME
   if [[ ! $NEWHOSTNAME == *['!'@#\$%^\&*()\_+\']* ]];then
      break;
   else
      echo "Contains a character not allowed for a hostname, please try again"
   fi
done
echo
echo "*** Taking a 5-7 seconds to gather information ***"
echo

#Picking VM ID number
vmidnext=$(pvesh get /cluster/nextid)
declare -a vmidsavail=$(pvesh get /cluster/resources | awk '{print $2}' | sed '/storage/d' | sed '/node/d' | sed '/id/d' | sed '/./,/^$/!d' | cut -d '/' -f 2 | sed '/^$/d')

#echo ${vmidsavail[@]}

for ((i=1;i<=99;i++));
do
   systemids+=$(echo " " $i)
done

USEDIDS=("${vmidsavail[@]}" "${systemids[@]}")
declare -a all=( echo ${USEDIDS[@]} )

function get_vmidnumber() {
    read -p "${1} New VM ID number: " number
    if [[ " ${all[*]} " != *" ${number} "* ]]
    then
        VMID=${number:-$vmidnext}
    else
        get_vmidnumber 'Enter a different number because either you are using it or reserved by the sysem'
    fi
}
echo "Enter desired VM ID number or press enter to accept default of $vmidnext: "
get_vmidnumber ''

# Default cores is 4 and memory is 2048
while true
do
 echo "The default CPU cores is set to 4 and default memory (ram) is set to 2048"
 read -r -p "Would you like to change the cores or memory (Enter Y/n)? " corememyesno

 case $corememyesno in
     [yY][eE][sS]|[yY])
 echo
 read -p "Enter number of cores for VM $VMID: " CORES
 echo
 read -p "Enter how much memory for the VM $VMID (example 2048 is 2Gb of memory): " MEMORY
 break
 ;;
     [nN][oO]|[nN])
 CORES="4"
 MEMORY="2048"
 break
        ;;
     *)
 echo "Invalid input, please enter Y/n or Yes/no"
 ;;
 esac
done
echo


## This next section is asking size of the root disk
while true
do
 echo
 read -p "Please enter root disk size in GB's : " DISKSIZE
 break
done
echo

echo "The VM number will be $VMID"
echo "VM name will be $NEWHOSTNAME"
echo "VM memory will be $MEMORY"
echo "VM core will be $CORES"
echo "VM Disk will be $DISKSIZE"


qm create $VMID --name $NEWHOSTNAME --cdrom local:iso/fedora-coreos-39.20231204.3.3-live.x86_64.iso --bootdisk scsi0 --scsihw virtio-scsi-pci --scsi0 file=local-lvm:$DISKSIZE \
       --cores $CORES --sockets 1 --memory $MEMORY --cpu cputype=x86-64-v2-AES -ostype l26  --net0 bridge=vmbr0,tag=10,virtio --boot order='scsi0;ide2'
