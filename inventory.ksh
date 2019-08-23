#!/bin/sh
################################################################################
#
# Documentation
# ==============================================================================
# This script is used to generate an inventory of the Unix servers generaating a
# comprehensive csv report
# ==============================================================================
#
# Version Control
# ==============================================================================
#	Ver 1.0.0 - Created by Franco Bontorin
#			  - Date: Feb 2013
################################################################################


##########################
# VARIABLE DECLARATION   #
##########################

PLATFORM=$(uname)
HOSTNAME=$(uname -n)

function netmask_h2d {
	
	# Convert Solaris Netmask from HEX to DEC
	set -- `echo $1 | sed -e 's/\([0-9a-fA-F][0-9a-fA-F]\)/\1\ /g'`
	perl -e '$,=".";print 0x'$1',0x'$2',0x'$3',0x'$4
}

##################
# MAIN FUNCTIONS #
##################


function GatherInformation {

	# GLOBAL VARIABLES
	
		/usr/seos/bin/seversion > /tmp/seversion_output 2>&1
		ACX=$(cat /tmp/seversion_output | awk '/Access/ {print $5}')		
		[[ -z "$ACX" ]] && ACX=$(cat /tmp/seversion_output | awk '/seversion/ {print $3}' | head -1)
		[[ -z "$ACX" ]] && ACX=NA

	case $PLATFORM in
	
	(AIX)
	
	# GENERAL SERVER INFORMATION
	
		OS_LEVEL=$(oslevel -s)
		/usr/sbin/prtconf > /tmp/prtconf_output 2> /dev/null
		OS_MODEL=$(awk '/System Model:/ {print $3}' /tmp/prtconf_output | sed 's/,/ /') 
		PROCESSORS=$(awk '/Number Of Processors:/ {print $4}' /tmp/prtconf_output) 
		CORES=$(iostat | awk '/lcpu/ {print $3}' | awk -F '=' '{print $2}')
		CLOCK=$(awk '/Processor Clock Speed:/ {print $4}' /tmp/prtconf_output) 
		CPU_TYPE=$(awk '/CPU Type:/ {print $3}' /tmp/prtconf_output) 
		MEMORY=$(svmon -G | awk ' /memory/ {printf ("%5.2f",$2/256/1024)}'| sed 's/ //g') 
		SWAP=$(svmon -G | awk ' /pg space/ {printf ("%5.2f",$3/256/1024)}'| sed 's/ //g') 
								
	# NETWORK SETTINGS
		
		IP_ADDRESS=$(awk '/IP Address:/ {print $3}' /tmp/prtconf_output) 
		SUBNET=$(awk '/Sub Netmask:/ {print $3}' /tmp/prtconf_output) 
		GATEWAY=$(awk '/Gateway:/ {print $2}' /tmp/prtconf_output) 
				
	# SOFTWARE
			
		ODM_VERSION=$(lslpp -L| awk '/EMC.*aix.rte/ {print $2}' | sort -rn | head -1)
		POWERPATH=$(powermt version | awk '{print $7$8$9$10$11}')
		[[ -z "$POWERPATH" ]] && POWERPATH=NA
		
	# PRINT RESULTS
	
		printf "=== INVENTARIO DE INFRAESTRUCTURA ===\n"
		printf " Hostname: $HOSTNAME\n Plataform: $PLATFORM\n OS Level: $OS_LEVEL\n OS Model: $OS_MODEL\n Cores: $CORES\n Proccessors: $PROCESSORS\n ODM Version: $ODM_VERSION\n Clock: $CLOCK MHz\n Memory: $MEMORY KB\n Swap: $SWAP KB\n CPU Type: $CPU_TYPE\n IP Address: $IP_ADDRESS\n Subnet: $SUBNET\n Gateway: $GATEWAY "
	;;
	
	(Linux)
	
	# GENERAL SERVER INFORMATION
	
		OS_LEVEL=$(uname -r)
		#SYSTEM_MODEL=$(dmidecode -t system | awk '/Manufacturer:/ {print $2$3}' | sed 's/,/ /' 2> /dev/null)
		SYSTEM_MODEL=$(grep "" /sys/class/dmi/id/sys_vendor)
		OS_MODEL=$(grep 'PRETTY_NAME' /etc/os-release | sed -e 's/\"//g; s/PRETTY_NAME=//g')
		PROCESSOR_TYPE=$(grep  "model name" /proc/cpuinfo | uniq | sed s/'model name'//g | sed s/\:// | sed "s/^[ \t]*//")
		PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
		CLOCK=$(awk '/MHz/ {print $4}' /proc/cpuinfo | head -1)
		MEMORY=$(free -h | awk '/Mem:/ {print $2}')
		MEMORY_USED=$(free -h | awk '/Mem:/ {print $3}')
		MEMORY_AVAILABLE=$(free -h | awk '/Mem:/ {print $7}')
		SWAP=$(free -h | awk '/Swap/ {print $2}')
		SWAP_FREE=$(free -h | awk '/Swap/ {print $4}')
		
      

	# PRINT RESULTS

		printf "======= INVENTARIO DE INFRAESTRUCTURA =======\n"
		printf "OPERATING SYSTEM\n  Plataform: $PLATFORM\n  Kernel: $OS_LEVEL\n  OS Model: $OS_MODEL\n\n"
		printf "HARDWARE\n  Hostname: $HOSTNAME\n  System Model: $SYSTEM_MODEL\n  Proccesor Type: $PROCESSOR_TYPE\n  Proccessors:$PROCESSORS\n  Clock: $CLOCK MHz\n  Memory total: $MEMORY GB\n  Memory used: $MEMORY_USED\n  Memory available: $MEMORY_AVAILABLE\n  Swap total: $SWAP \n  Swap free: $SWAP_FREE\n\n"
		printf "STORAGE\n "

	# STORAGE 
	    DEVICES=$(df -h -x tmpfs | grep /dev/ | awk '{print $1}')
		for i in $DEVICES; do
			printf "\t$i\n"
			SIZE=$(df -h -x tmpfs | grep $i | awk '{print "Size:" $2 "GB"}')
			USED=$(df -h -x tmpfs | grep $i | awk '{print "Used:" $3 "GB"}')
			USE=$(df -h -x tmpfs | grep $i | awk '{print "Porcentaje de uso:" $5}' | sed s/\%//g )
			MOUNT=$(df -h -x tmpfs | grep $i | awk '{print "Mount:" $6}')
			printf "\t\t$SIZE\n\t\t$USED\n\t\t$USE\n\t\t$MOUNT\n\n"
		done

		
		printf "NETWORK\n  Interfaces:\n"
	# NETWORK SETTINGS
		INTERFACES=$(ifconfig -s | awk '{print $1}'| sed '1d')
		for i in $INTERFACES; do
			printf "\t$i\n"
			IPv6=$(ifconfig -v $i | grep -e 'inet6' | awk '{print "IP_'$i'="  $2}')
			NETMASKv6=$(ifconfig -v $i | grep -e 'inet6' | awk '{print "NETMASK_'$i'="  $4}')
			BROADCASTv6=$(ifconfig -v $i | grep -e 'inet6' | awk '{print "BROADCATS_'$i'=" $ 6}')
			IPv4=$(ifconfig -v $i | grep -e 'inet ' | awk '{print "IP_'$i'="  $2}')
			NETMASKv4=$(ifconfig -v $i | grep -e 'inet ' | awk '{print "NETMASK_'$i'=" $4}')
			BROADCASTv4=$(ifconfig -v $i | grep -e 'inet ' | awk '{print "BROADCATS_'$i'="  $6}')
			printf "\t\t* Versión 4\n\t\t$IPv4\n\t\t$NETMASKv4\n\t\t$BROADCASTv4\n\t\t* Versión 6\n\t\t$IPv6\n\t\t$NETMASKv6\n\t\t$BROADCASTv6\n\n"
		done
	;;
	
	(SunOS)
	
	# GENERAL SERVER INFORMATION
	
		OS_LEVEL=$(uname -v | awk -F'_' '{print $2}')
		
		SYSTEM_MODEL=$(prtdiag -v 2> /dev/null | awk '/System Configuration/ {print $6,$7,$8}'); [[ -z "$SYSTEM_MODEL" ]] && SYSTEM_MODEL=$(prtconf 2> /dev/null | sed '5!d' | sed 's/,/ /')
		PROCESSORS=$(psrinfo -p)
		CORES=$(kstat cpu_info | grep core_id | uniq | wc -l | sed 's/ //g'); [[ "$CORES" == "0" ]] && CORES=$(psrinfo -pv | head -1 | nawk '{sub(/.*has /,"");sub(/ virtual.*/,"");print;}')
		CLOCK=$(kstat cpu_info | grep clock_MHz | head -1 | awk '{print $2}')
		MEMORY=$(prtconf | awk '/Memory/ {printf ("%5.0f\n", $3/1024)}' | sed 's/ //g')
		USED_SWAP=$(swap -s | awk '{print $9}' | cut -dk -f1 | awk '{printf ("%5.0f \n",$1/1000/1000)}' | sed 's/ //g')
		FREE_SWAP=$(swap -s | awk '{print $11}' | cut -dk -f1 | awk '{printf ("%5.0f \n",$1/1000/1000)}' | sed 's/ //g')
		SWAP = USED_SWAP + FREE_SWAP
					
	# NETWORK DETAILS
	
		IP_ADDRESS=$(grep -w $HOSTNAME /etc/hosts | grep -v ^# | head -1 | awk '{print $1}')
		SUBNET_HEX=$(ifconfig -a | awk "/$IP_ADDRESS/" | awk '{print $4}')
		SUBNET=$(netmask_h2d $SUBNET_HEX)
		GATEWAY=$(netstat -nr | awk '/default/ {print $2}' | head -1)
		
	# SOFTWARE
	
		POWERPATH=$(pkginfo -l EMCpower 2> /dev/null | awk /'VERSION/ {print $2}')
		[[ -z "$POWERPATH" ]] && POWERPATH=NA
			
	# PRINT RESULTS
	
        printf "=== INVENTARIO DE INFRAESTRUCTURA ===\n"
		printf " Hostname: $HOSTNAME\n Plataform: $PLATFORM\n OS Level: $OS_LEVEL\n System Model: $SYSTEM_MODEL\n Cores: $CORES\n Proccessors: $PROCESSORS\n Clock: $CLOCK MHz\n Memory: $MEMORY KB\n Swap: $SWAP KB\n CPU Type: $CPU_TYPE\n IP Address: $IP_ADDRESS\n Subnet: $SUBNET\n Gateway: $GATEWAY\n Used Swap: $USED_SWAP\n Free Swap: $FREE_SWAP"

	;;
	
	esac
	
	}
	
##########
#  MAIN  #
##########

	GatherInformation
 