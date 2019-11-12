#! /bin/bash

# common constants
readonly me="$0"

# text formating constants
readonly b="\033[1m"
readonly n="\033[0m"
readonly r="\033[0;31m"

# csv related constants
readonly wd_dur=$(( 8 * 3600 ))
readonly timestamp=$(date +%T)
readonly date_regex="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

# csv related default variabled
csv_headers=("date" "time" "message")
table_headers=("date" "start" "spent" "end" "break" "overtime" "total")

# common default veriables
from_csv="/var/log/wh_table.csv"

# default pretty formatting variables
is_pretty=false
max_table_width=$(tput cols)
max_table_col_width=$(( max_table_width / ${#table_headers[@]} ))
declare -A col_names_to_width=()

# write multiline help message into the variable
read -d '' help << EOF
usage: ${0} [options]

options:
	-f	specify absolute CSV file path (default is /var/log/wh_table.csv)
	-d	date to read (default is latest), 'YYYY-MM-DD' 
		To specify period, pass the date in format 'YYYY-MM-DD:YYYY-MM-DD'
	-p 	pretty formatting of the result, 'true' or 'false' (default is false)
	-h	display script helper
EOF

# check whether the arguments are passed
if [ $# -eq 0 ]; then
	echo -e "No arguments passed!"\\n
	echo "${help}"
	exit 1
fi


# read script options
while getopts f:d:p:h FLAG; do
	case $FLAG in
	f)	
		# check whether the file path has even passed
		if [ -n "$OPTARG" ]; then from_csv=$OPTARG
		else echo -e "File path is empty"\\n; echo "$help"; exit 1; fi
	;;
	p)	
		if [[ $OPTARG =~ (false|true) ]]; then is_pretty=$OPTARG; fi
	;;
	d)
		# check whether the date has even passed
		if [ -n "$OPTARG" ]; then
			
			# split the dates period
			IFS=":" read -r -a period <<< "$OPTARG"
			period_size=${#period[@]}

			# if period was defined, it should consist of 2 dates
			if [ $period_size -gt 2 ]; then
				echo -e "Invalid date period: '${OPTARG}'"\\n
				echo "$help"
				exit 1;
			fi

			# validate date(s) format
			for d in "${period[@]}"; do
				date "+%F" -d "$d" >/dev/null 2>&1
				ec=$?
				if ! [[ "$d" =~ $date_regex && $ec -eq 0 ]]; then
					echo -e "Invalid date: $OPTARG"\\n
					echo "$help"
					exit 1;
				fi
			done

			# assign date option to start date variable 
			from_date=${period[0]}

			if [ $period_size -eq 2 ] && [ ${period[0]} != ${period[1]} ]; then
				# assign the end date
				to_date=${period[1]}

				# get epoch time to check date period
				from_epoch=$(date -d "$from_date" +%s)
				to_epoch=$(date -d "$to_date" +%s)

				if (( from_epoch > to_epoch )); then
					echo "The start date ${from_date} is greater" \
					"than the end date ${to_date}"
					exit 1;
				fi

				# fill the dates list, which consist
				# of the dates within the given period
				d="$from_date"
				until [[ $d > $to_date ]]; do
					dates+=("$d")
					echo -ne "adding dates: ${#dates[@]}"\\r
					d=$(date -I -d "$d + 1 day")
				done
			else
				# assign start date to end date
				to_date="$from_date"
				# add only start date to dates list
				dates+=("$from_date")
			fi

			# DEBUG
			# echo "dates: ${dates[@]}"
			# echo "period: ${period[@]}"
			# echo "from $from_date to $to_date"
		fi
	;;
    h)	echo "$help"; exit 0 ;;
    \?)
     	echo -e "Option not allowed"\\n
     	echo "$help"
     	exit 1
    ;;
  esac
done
shift $(( OPTIND - 1 ))


# check whether the file is present
if [ ! -f $from_csv ]; then
	echo "File ${from_csv} not found. Please specify the right file path"
	exit 1
else
	# set complete list of available dates within the given csv file
	# do not skip header while counting 
	csv_size=$(cat -n $from_csv | awk 'END { print NR }')
	csv_dates=($(awk 'BEGIN {FS = ","} FNR > 1 { print $1 }' $from_csv | uniq))
fi


# if -d option is not set, print all dates
if [ -z ${period+x} ] || [ ${#period[@]} -eq 0 ]; then
	dates=(${csv_dates[@]})
fi


for d in "${dates[@]}"; do
	echo -ne "dates processed: ${#filtered[@]}"\\r

	# count of records for a specific date
	count=$(grep -r "$d" $from_csv | wc -l)
	
	# check whether there are at least 2 records with that date in csv
	# 2 means unlocked|started and lock|finished records
	if [[ $count -lt 2 && "$(date +%F)" != "$d" ]]; then continue; fi

	# add the date to the new filtered array
	filtered+=("$d")

	# get the last date line number to read
	# from_line=$(awk "/${from_date}/{ print NR; exit }" "$from_csv")
	to_line=$(awk "/${d}/{ a = NR } END { print a }" "$from_csv")
		
	# define entry variables before looping over the date records
	line=0
	prev_status="locked"

	while IFS="," read -r day time status; do
		# increment the line number
		(( line++ ))

		# the first status should be of 'unlocked'or 'started'
		if [[ $status != $prev_status ]]; then
			if [[ $status =~ (unlocked|started) ]]; then

				# remember 'unlocked' time
				unlock_time=$(date -u -d "$time" +"%s")

				# remember the start of the day if it was not set yet
    			if [ -z $wd_start ]; then wd_start=$unlock_time; fi

				# if it's the last record for that date
				# but not the 'locked' record
				if [ $line -eq $count ]; then

					# if it's the last record of the file
					# and if the date is today
					if [ $to_line -eq $csv_size ] &&
						[ "$(date +%F)" == "$day" ]; then

						# the working day has not ended yet
    					# remember 'locked' time as timestamp
    					lock_time=$(date -u -d "$timestamp" +"%s")

    					# calculate spent time till current moment
    					wd_spent=$(( wd_spent + ( lock_time - unlock_time) ))
    					
    					# calculate estimated working day end time
    					remained=$(( wd_dur - wd_spent ))
    					if [[ $remained -gt 0 ]]; then
    						wd_end=$(( remained + lock_time ))
    					else
    						wd_end=$lock_time
    					fi

    					# calculate break time
    					wd_break=$(( lock_time - wd_start - wd_spent ))
    				else
    					# the time logging has been broken
    					# or the next day was started
    					# then reset to the last 'locked' status
    					# because of the inability to accurately track
    					# the end of the working day
    					unset unlock_time
					fi
    			fi
    		elif [[ $status =~ (locked|finished) ]]; then

    			# remember the 'locked' time
     			lock_time=$(date -u -d "$time" +"%s")

     			# calculate spent time till current moment
    			wd_spent=$(( wd_spent + (lock_time - unlock_time) ))
    			wd_end=$lock_time
    		else continue;
    		fi
    	else continue;
		fi

		# calculate the break, total and over time
		if [ $line -eq $count ]; then
			# calculate break
			wd_break=${wd_break:-$(( wd_end - wd_start - wd_spent ))}

			# default overtime
			wd_over="0"
			# calculate overtime if spent time
			# greater then working day durration
			if [[ $wd_spent -gt $wd_dur ]]; then
				wd_over=$(( wd_spent - wd_dur ))
			fi

			# calculate total time
			wd_total=$(( wd_spent + wd_break ))
		fi

		# remember the previous status of the record
		prev_status="$status"

	done <<< $(awk -vdate="$d"\
		'BEGIN { FS = "," } $1 == date { print $0 }' $from_csv)

	# set calculated time to result array
	results+=("${d} \
		$(date -u -d "0 $wd_start sec" +"%H:%M") \
		$(date -u -d "0 $wd_spent sec" +"%-Hh%-Mm%-Ss") \
		$(date -u -d "0 $wd_end sec" +"%H:%M") \
		$(date -u -d "0 $wd_break sec" +"%-Hh%-Mm%-Ss") \
		$(date -u -d "0 $wd_over sec" +"%-Hh%-Mm%-Ss") \
		$(date -u -d "0 $wd_total sec" +"%-Hh%-Mm%-Ss")"
	)
	
	unset wd_start wd_spent wd_end wd_break wd_over wd_total
done


if [[ ${#results[@]} -ne 0 ]]; then
	if $is_pretty; then
		# find the longest string in the table columns
		# in order to calculate min column width
		for (( i = 0; i < ${#table_headers[@]}; i++ )); do
			longest_len=0
			header="${table_headers[i]}"
			for row in "${results[@]}"; do
				recs=($row); rec="${recs[i]}"; rec_len="${#rec}";
				if (( rec_len > longest_len )); then
					longest_len=$rec_len
					longest_rec=$rec
				fi
			done

			# 2 means default column offset
			pretty_format+="%-$(( longest_len + 2 ))s "
		done

		printf "$pretty_format\n" "${table_headers[@]}"

		for row in "${results[@]}"; do
			# echo "$pretty_format"
			recs=($row)
			printf "$pretty_format\n" "${recs[@]}"
		done
		else

		for row in "${results[@]}"; do
			recs=($row)
			echo "${recs[@]}"
		done
	fi
fi
