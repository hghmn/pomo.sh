#!/bin/bash


# Environment Variables and Defaults
# ==================================================
: "${POMO_FILE_LOC:=$HOME/.local/share/pomo/log}"
: "${POMO_INTERVAL:=26}"
: "${POMO_BREAK_INTERVAL:=4}"


# Global Variables unique to this file
now=$(date +%s)
minimal_status=false

# Task variables
task_title=""
task_tags=""
start_time="$(date +%s)"
stop_time="$(date -v+${POMO_INTERVAL}M +%s)"


# Functions
# ==================================================
function pomo_usage {
    # sanitize the command used
    cmd="${0##*\/}"

    # print command and usage
    echo "usage: ${cmd} [-i interval_minutes] [-t task_name] start"
    echo "       ${cmd} stop"
}

# 'start' append a task to the file
function pomo_start {
    # check to see if a task is currently running
    last_task=$(get_last_tasks 1)
    last_task_finish_time=$(echo $last_task | awk -F ':' '{ print $1 }')
    if [[ $last_task_finish_time -gt $now ]]; then
        cmd="${0##*\/}"
        echo "Currently in a task, try \"${cmd} continue\" or \"${cmd} stop\""
        exit 0;
    fi

    if [[ -z $task_title ]]; then
        # echo "Task title is empty"
        read -p "> Enter a Pomodoro task title: " task_title
    fi

    if [[ -z $task_tags ]]; then
        # echo "Task tags are empty"
        read -p "> Enter one or more Pomodoro tags: " task_tags
    fi

    echo "Starting Pomodoro \"$task_title\" for ${POMO_INTERVAL}m"

    # Write out the new pomodoro task to file
    task_entry="$stop_time:$start_time:$task_title:$task_tags"
    echo $task_entry >> $POMO_FILE_LOC
}

# Fetch and duplicate the last task, changing the
function pomo_continue {
    last_task=$(get_last_tasks 1)
    last_task_finish_time=$(echo $last_task | awk -F ':' '{ print $1 }')

    if [[ $last_task_finish_time -gt $now ]]; then
        # Change the stop time forward by the POMO_INTERVAL
        sed -i '' "$ s/.*/${stop_time}${last_task:10}/" $POMO_FILE_LOC
    else
        echo "${stop_time}:${start_time}${last_task:21}" >> $POMO_FILE_LOC
    fi
}

function pomo_stop {
    last_task=$(get_last_tasks 1)
    task_name=$(echo $last_task | awk -F ':' '{ print $3 }')

    line_num="$(wc -l < $POMO_FILE_LOC)"
    line_num="${line_num//[[:space:]]/}"
    last_task="$(get_last_tasks 1)"
    last_task_finish_time=$(echo $last_task | awk -F ':' '{ print $1 }')

    # Check the stop time, or overwrite it
    if [[ $last_task_finish_time -gt $now ]]; then
        # replace everything on the last line with the new end time
        # TODO: find less destructive means of updating time
        sed -i '' "$ s/.*/${now}${last_task:10}/" $POMO_FILE_LOC
    else
        echo "\"${task_name}\" was finished $(fuzzy_time $(( $now - $last_task_finish_time))) ago"
    fi
}

function pomo_status {
    # Check if file has been created yet
    if [[ ! -e $POMO_FILE_LOC ]]; then
        echo "Warning - No Pomodoro tasks have been started"
        exit 0
    fi

    # Read in the last line of the file
    last_task=$(get_last_tasks 1)
    task_name=$(echo $last_task | awk -F ':' '{ print $3 }')

    # Read the last task and parse it
    while IFS=: read col1 col2 col3 col4; do
        stop_time="$col1"
        start_time="$col2"
        task_title="$col3"
        task_tags="$col4"
    done <<< "$last_task"

    # Determine time offsets
    time_remaining=$(( $stop_time - $now ))
    time_elapsed=$(( $now - $start_time ))

    if [[ $minimal_status = true ]]; then
        echo "[pomo][$task_title][$(fuzzy_time $time_remaining)]"
        return 0;
    fi

    # TODO: handle breaks better
    if [[ $time_remaining -lt $(( -60 * $POMO_BREAK_INTERVAL )) ]]; then
        echo "Break time is over!"
    fi

    if [[ $time_remaining -lt 0 ]]; then
        echo "\"task_name\" has ended"
    fi

    echo "time elapsed   : $(print_time $time_elapsed)"
    echo "time remaining : $(print_time $time_remaining)"
}

function print_time {
    # strip pos/neg sign from time value
    sign="${1//[0-9]/}"
    value="${1/-/}"

    # left-pad time segements with '0'
    hours="00$(( $value / 60 / 60 ))"
    minutes="00$(( $value / 60 ))"
    seconds="00$(( $value % 60 ))"
    echo "${sign}${hours: -2}:${minutes: -2}:${seconds: -2}"
}

function fuzzy_time {
    time_elapsed=$1
    sign="+"

    # positive or negative
    if [[ $time_elapsed -lt 0 ]]; then
        sign="-"
        time_elapsed=${time_elapsed/-/}
    fi

    if [[ $time_elapsed -le 60 ]]; then
        fuzzy_time="${time_elapsed}s"
    elif [[ $time_elapsed -le 3600 ]]; then
        fuzzy_time="$(echo $(($time_elapsed / 60)))m"
    else
        fuzzy_time="$(echo $(($time_elapsed / 60 / 60)))h"
    fi

    echo "${sign}${fuzzy_time}"
}

function get_last_tasks {
    # if no parameters, get only the last line in the file
    if [[ -z $1 ]]; then
        lines=1
    else
        lines=$1
    fi

    # Tail the file
    tail -n $lines $POMO_FILE_LOC
}

# TODO: delete or use this function
function log_tasks {
    # Read in tasks from a line
    let i=0
    while IFS=: read col1 col2 col3 col4; do
        # echo "--------------------"
        # echo "line  : $i"
        echo "start : $col2"
        echo "stop  : $col1"
        echo "title : $col3"
        echo "tags  : $col4"
        let i++
    done <<< "$1"
}


# Process Command Options
# ==================================================
while getopts ":i:t:s:mh" opt; do
    case $opt in
        i)
            POMO_INTERVAL="$OPTARG"
            ;;
        t)
            task_title="$OPTARG"
            ;;
        s)
            task_tags="$OPTARG"
            ;;
        m)
            minimal_status=true
            ;;
        h)
            # Print help, then exit
            pomo_usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done


# Process Command Arguments
# ==================================================
while [ "$#" -gt 0 ]; do
    case $1 in
        start)
            action="start";
            ;;
        stop)
            action="stop"
            ;;
        continue)
            action="continue"
            ;;
        status)
            action="status"
            ;;
        :)
          echo "ERROR: unknown action specfified '$1'" >&2
          exit 1
          ;;
    esac

    # Shift off the arg
    shift 1
done


# Check if an action has been set
# ==================================================
if [[ -z $action ]]; then
    echo "no pomo action specfified"
else
    # Run the action
    pomo_$action
fi


# Terminate
# ==================================================
exit 0
