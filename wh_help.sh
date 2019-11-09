#! /bin/bash

declare -g color_log=true
declare -g simple_log=false

# color constants
readonly def='\e[39m'
readonly gray='\e[90m'
# readonly ligth_gray='\e[37m'
readonly red='\e[31m'
readonly cyan='\e[96m'
readonly magenta='\e[95m'
readonly yellow='\e[93m'
readonly green='\e[92m'
readonly blue='\e[94m'
readonly nc='\e[0m'

# logger
log() {
	if [[ -z $* ]]; then log w "log(): args are not passed"; fi
	local text_col=;
	local type="[${1^^}]"
	local text=$2
	local rt=$3;
	local ts=$(date +%F\ %T)
	case $1 in
		p) type_col=$green; text_col=$green; text="test: $2" ;;
		f) type_col=$red; text_col=$red; text="test: $2" ;;
		s) type_col=$yellow; text_col=$yellow; text="test: $2" ;;
    	e) type_col=$red; text_col=$red;;
     	i) type_col=$blue; text_col=$blue;;
     	w) type_col=$yellow; text_col=$yellow;;
     	v) type_col=$gray; text_col=$gray ;;
     	*) return 1;
	esac

	if $simple_log; then
		echo -e "${type} $2 ${rt:+$rt}"
	else
		if $color_log; then
			echo -e "${gray}[${ts}]${type_col}${type}${nc} ${text_col}${text}${nc}"\
			"${magenta}${rt:+(${rt} ms)}${nc}"
		else
			echo -e "[${ts}]${type} $2 ${rt:+$rt}"
		fi
	fi
}

# command execution wrapper
run() {
	st=$(date +%s%N)

	if [[ -z $* ]]; then log e "run(): command is not specified"; fi
 	local err=$($* 2>&1 > /dev/null)
 	ec=$?

 	et=$(date +%s%N)
 	rt=$(( (et - st) / 1000000 ))
 	log v "$*" $rt
 	
 	if [[ $ec -ne 0 || -n $err ]]; then log e "$err"; return 1; fi

 	return 0
}

# join array items by given delimeter
join() {
	if [[ -z $1 ]]; then log e "join(): delimeter is not passed"; fi
	local IFS="$1"; shift; echo "$*"
}

# split items by given delimeter
split() {
	if [[ -z $* ]]; then log e "split(): args are not passed"; fi
    IFS="$1" read -a arr <<< "$2"; echo "${arr}"
}

# check whether the given string contains another
contains() {
	if [[ -z $* ]]; then log e "contains(): args are not passed"; fi
	if [[ "$1" == *"$2"* ]]; then echo true;
  	else echo false; fi
}
