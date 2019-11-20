#! /bin/bash

# import helper
helper_file="$(dirname $0)/wh_help.sh"
if [ -f "$helper_file" ]; then
	source "$helper_file"
else
	echo "wh_help.sh helper does not exist"
	exit 1
fi

# default variables
readonly me="$(basename $BASH_SOURCE):"
readonly header="date,time,message"
readonly file_path="${1:-/var/log/wh_table.csv}"
readonly file_name=${file_path##*/}
readonly file_dest=${file_path%/*}
readonly msg_started="started"
readonly msg_finished="finished"
readonly msg_locked="locked"
readonly msg_unlocked="unlocked"
is_dbus_started=false
is_under_root=false
user=$USER
color_log=${COLOR_LOG:-true}
simple_log=${SIMPLE_LOG:-false}

# get dbus-monitor pid
get_dbus_pid() { echo $(pgrep "dbus-monitor"); }


# check owner of the file or folder
is_right_owner() {
	owner=$(ls -ld $1 | awk '{print $3}')

	if ! $is_under_root && [ "$owner" != "$user" ]; then
		log e "$me $1 has '$owner' user as owner, current is '$user'"
		return 1
	fi

	return 0
}

# write csv row into the file
write() { 
	log i "$me writing '$1' into the $file_name"
	( echo "$(date +%F),$(date +%T),$1" >> $file_path ) 2>/dev/null

	if [ $? -ne 0 ]; then
		log e "$me an error occured while writing to the $file_path"
		exit 1
	fi
}


write_header() {
	log i "$me writing a header to $file_path"
	if $is_under_root; then sh -c "echo $header >> $file_path"
	else 
		if is_right_owner $file_dest; then
			echo $header >> $file_path
		else
			log e "$me error while writing a header"
			exit 1
		fi
	fi
}


# wait process to start
wait_dbus() {
	sec=10
	log i "$me waiting dbus-monitor to start"

	while [ $sec -gt 0 ]; do
		log v "seconds left: $sec"
		(( sec-- ))

		if [[ -n $($*) ]]; then
			dbus_pid=$($* | tr -d '[:space:]')
			proc_name=$(ps -p $dbus_pid -o comm=)
			if [[ $proc_name =~ "dbus" ]]; then
				log v "dbus-monitor found: $dbus_pid"
				break
			else
				log e "$me wrong process found: $proc_name"
				exit 1
			fi
		fi
		sleep 1
	done
}


# trap
on_trap() {

	if [ -f "$file_path" ] && $is_dbus_started; then
		write "$msg_finished"
	else
		log e "$me error while writing '$msg_finished' log"
	fi

	if [[ -n $(get_dbus_pid) ]]; then
		log i "$me killing dbus-monitor process"
		run "kill -INT $(get_dbus_pid)"
		log i "$me dbus-monitor process was killed"
	fi
}

trap "log w '$me was interrapted'; exit" SIGINT
trap "log w '$me was terminated'; exit" SIGTERM
trap "on_trap; log w '$me exit'; exit" EXIT


# if run under root, override 'user' variable
#+ to point to the current logged user
if [ $EUID -eq 0 ]; then
	is_under_root=true
	if [ -z $SUDO_USER ]; then
		user=$(who | cut -d' ' -f1)
	else
		user=$SUDO_USER
	fi

	if [ -n $user ]; then
		log i "$me dbus user is set to '$user'"
	else
		log e "$me can not determine user to start dbus-monitor"
		exit 1
	fi
fi


# verify .csv file
if [ -f $file_path ]; then

	if is_right_owner $file_path; then
		file_header=$(head -n 1 "$file_path")

		if [[ "$file_header" != "$header" ]]; then
			if [[ -n "$file_header" ]]; then
				log w "$me $file_path header is invalid"
				log v "$file_header"
			else
				log w "$me $file_path header is empty"
			fi
			
			log i "$me replacing $file_path header with valid one"

			if [ -s "$file_path" ]; then
				run sed -i "1s/.*/${header}/" $file_path
			else
				write_header
			fi
		else
			log i "$me $file_path exists and is of valid format"
		fi
	else
		exit 1
	fi
else
	log w "$me file is missing along the path: '$file_path'"
	log i "$me creating a folder if isn't exist: '$file_path'"

	run "mkdir -p $file_dest"
	write_header
fi


# gnome-session
gs_pid=$(pgrep "gnome-session" -u $user)

if [ -n $gs_pid ]; then
	log i "$me PID=$$"
	log i "$me gnome-session PID=$gs_pid"

	# tr is to prevent warning: 'ignored null byte in input grep'
	addr=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/${gs_pid}/environ | tr '\0' '\n')

	export DBUS_SESSION_BUS_ADDRESS=${addr#*=}
	log v "export DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
else
	log e "$me can not determine gnome-session PID"
	exit 1
fi


# if dbus-monitor is already running - kill
if [[ -n $(get_dbus_pid) ]]; then
	prev_pid=$(get_dbus_pid)
	log w "$me dbus-monitor process already exists"
	log i "$me killing dbus-monitor process"

	run "kill -INT $prev_pid"
	while kill -0 $(ps -o ppid= $prev_pid) 2> /dev/null; do sleep 1; done

	log i "$me old dbus-monitor process is no longer exist"
fi



# start dbus-monitor proccess
log i "$me starting new dbus-monitor process"

if $is_under_root; then
	coproc su -c 'dbus-monitor --session "type=signal,interface=org.gnome.ScreenSaver"' $user
	wait_dbus pgrep -P $COPROC_PID
else
	coproc dbus-monitor --session "type='signal',interface='org.gnome.ScreenSaver'"
	wait_dbus pgrep "dbus-monitor"
fi


# attach listener on dbus-monitor
if [[ -n $dbus_pid ]]; then

	log i "$me dbus-monitor PID=$dbus_pid"
	dbus_fd="/proc/${dbus_pid}/fd/1"
	
	if [ -d "/proc/${dbus_pid}/fd" ]; then

		write "$msg_started"
		is_dbus_started=true

		while read line; do
			if echo "$line" | grep "boolean true" &> /dev/null; then
				write "$msg_locked"
			elif echo "$line" | grep "boolean false" &> /dev/null; then
				write "$msg_unlocked"
			fi
		done < "$dbus_fd"
	else
		log e "$me dbus-monitor file descriptor is apsent: $dbus_fd"	
	fi
else 
	log e "$me an error occured while starting dbus-monitor process"
	exit 1
fi
