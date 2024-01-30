#!/bin/bash

# January 2024
# Virantha Mendis
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

#Checking to see what VMBR interface you want to use
echo
echo "Please select VMBR to use for your network"
declare -a vmbrs=$(awk '{if(/vmbr/) print $2}' /etc/network/interfaces)
declare -a vmbrsavail=( $(printf "%s\n" "${vmbrs[@]}" | sort -u) )

cnt=${#vmbrsavail[@]}
for (( i=0;i<cnt;i++)); do
    vmbrsavail[i]="${vmbrsavail[i]}"
done
total_num_vmbrs=${#vmbrsavail[@]}
vmbrsavail2=$( echo ${vmbrsavail[@]} )

select option in $vmbrsavail2; do
if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $total_num_vmbrs ];
then
#        echo "The selected option is $REPLY"
#        echo "The selected storage is $option"
        vmbrused=$option
        break;
else
        echo "Incorrect Input: Select a number 1-$total_num_vmbrs"
fi
done

echo "Your network bridge will be on " $vmbrused
echo
echo



#VLAN information block
while true
do
 read -r -p "Do you need to enter a VLAN number? [Y/n] " VLANYESORNO

 case $VLANYESORNO in
     [yY][eE][sS]|[yY])
 echo
 while true
 do
  read -p "Enter desired VLAN number for the VM: " VLAN
  if [[ $VLAN -ge 0 ]] && [[ $VLAN -le 4096 ]]
  then
     break
  fi
 done
 echo
 break
 ;;
     [nN][oO]|[nN])
 echo
 break
        ;;
     *)
 echo "Invalid input, please enter Y/N or yes/no"
 ;;
 esac
done

echo

echo "The VM number will be $VMID"
echo "VM name will be $NEWHOSTNAME"
echo "VM memory will be $MEMORY"
echo "VM core will be $CORES"
echo "VM Disk will be $DISKSIZE"


qm create $VMID --name $NEWHOSTNAME --cdrom local:iso/fedora-coreos-39.20231204.3.3-live.x86_64.iso --bootdisk scsi0 --scsihw virtio-scsi-pci --scsi0 file=local-lvm:$DISKSIZE --cores $CORES --sockets 1 --memory $MEMORY --cpu cputype=x86-64-v2-AES -ostype l26  --net0 bridge=vmbr0,tag=10,virtio --boot order='scsi0;ide2'


if [[ $VLANYESORNO =~ ^[Yy]$ || $VLANYESORNO =~ ^[yY][eE][sS] ]]
then
    qm set $VMID --net0 virtio,bridge=$vmbrused,tag=$VLAN
else
    qm set $VMID --net0 virtio,bridge=$vmbrused
fi

# Here we are going to set the network for DHCP
# This will allow internet access when booted off the FCOS Live CD
# to download ignition file for the installation which includes settingup of
# a static IP for the VM
qm set $VMID --ipconfig0 ip=dhcp
