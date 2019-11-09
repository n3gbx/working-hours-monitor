#!/bin/bash

. wh_help.sh

start_time=$(date +%s%N)

readonly mon_dest=/usr/local/bin
readonly mon_file="wh_mon.sh"

readonly help_dest=$mon_dest
readonly help_file="wh_help.sh"

readonly csv_path=${1:-/var/log/wh_table.csv}
readonly csv_dest=${csv_path%/*}
readonly csv_file=${csv_path##*/}

readonly daemon_dest=/etc/systemd/system
readonly daemon_file="wh_daemon.service"

get_curr_run_time() {
	end_time=$(date +%s%N)
	echo $(( (end_time - start_time) / 1000000 ))
}

get_logged_user() {
	echo $(who | cut -d' ' -f1)
}

capture_exit() {
	log i "exit" $(get_curr_run_time)
}

trap capture_exit EXIT

if [ "$EUID" -ne 0 ]; then
	log e "please run the installer with the sudo -E"
  	exit 1
fi

# checking compatibility

declare -i failed=0

log i "executing tests to check compatibility"

if (( BASH_VERSINFO[0] >= 4 )); then
	log p "bash-$BASH_VERSION"
else
	if [ -n ${BASH_VERSINFO[0]} ]; then
		log f "bash-4.0 and later is required, current is ${BASH_VERSINFO[0]}"
	else
		log s "unable to determine current bash version"
	fi
	(( failed++ ))
fi

xdg_env_var=$(env | grep XDG_CURRENT_DESKTOP)
xdg_env_val=${xdg_env_var##*:}

if [[ ${xdg_env_val,,} =~ (unity|gnome) ]]; then
	log p "desktop environment is $xdg_env_val"
	env_type=${xdg_env_val,,}
else
	if [ -n $xdg_env_val ]; then
		log f "GNOME or Unity environment is required, current is $xdg_env_val"
	else
		log s "unable to determine current desktop environment"
	fi
	(( failed++ ))
fi

if [ -f $mon_file ] && [ -f $daemon_file ]; then
	log p "$mon_file and $daemon_file are ready to be copied"
else
	log f "$0 is not in the same folder as $mon_file and $daemon_file"
	(( failed++ ))
fi

if (( failed > 0 )); then
	log e "compatibility testing isn't passed" $(get_curr_run_time)
	exit 1
else
	log i "compatibility testing is passed" $(get_curr_run_time)
fi

# installing

if [ ! -f "${csv_path}" ]; then
	log i "copying $csv_file to $csv_dest"
	run "mkdir -p $csv_dest"
	run "touch ${csv_path}"
	log i "change owner for $csv_file"
	run "chown -R $(get_logged_user):$(get_logged_user) $csv_path"
fi

log i "copying $mon_file and $help_file to $mon_dest"
run "cp -t $mon_dest $mon_file $help_file"

log i "make $mon_file and $help_file executable"
run "chmod +x ${mon_dest}/wh*.sh"

log i "copying $daemon_file to $daemon_dest"
run "cp $daemon_file $daemon_dest"

log i "making the $daemon_file executable"
run "chmod +x ${daemon_dest}/${daemon_file}"
