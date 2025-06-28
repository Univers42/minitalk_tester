#!/bin/bash

parse_arguments()
{
	RUN_BASIC=false
	RUN_EDGE=false
	RUN_PERFORMANCE=false
	RUN_ALL=false
	VERBOSE=false
	QUIET=false
	CLEAN_ONLY=false
	MESSAGE="just a message"
	SERVER_BINARY=""
	CLIENT_BINARY=""
	SHOW_USAGE=false
	RUN_TESTER_MINITALK=false
	PERFORMANCE_MODE=false

	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				SHOW_USAGE=true
				shift
				;;
			-v|--verbose)
				VERBOSE=true
				SHOW_USAGE=true   # <-- Add this line so -v triggers usage
				shift
				;;
			-q|--quiet)
				QUIET=true
				shift
				;;
			-b|--basic)
				RUN_BASIC=true
				shift
				;;
			-e|--edge)
				RUN_EDGE=true
				shift
				;;
			-p|--performance)
				RUN_PERFORMANCE=true
				PERFORMANCE_MODE=true
				shift
				;;
			-a|--all)
				RUN_ALL=true
				shift
				;;
			-c|--clean)
				CLEAN_ONLY=true
				shift
				;;
			-m|--message)
				MESSAGE="$2"
				shift 2
				;;
			--server-path)
				SERVER_BINARY="$2"
				shift 2
				;;
			--client-path)
				CLIENT_BINARY="$2"
				shift 2
				;;
			-tm|--tester-minitalk)
				RUN_TESTER_MINITALK=true
				shift
				;;
			-tmp|--tester-minitalk-performance)
				RUN_TESTER_MINITALK=true
				PERFORMANCE_MODE=true
				shift
				;;
			*)
				log_error "unknown option: $1"
				SHOW_USAGE=true
				shift
				;;
		esac
	done
}

# Extracts the first number (PID) from a given input (server output)
get_pid_from_output() {
    local output="$1"
    # Use grep to extract the first number (PID)
    echo "$output" | grep -oE '[0-9]+' | head -n 1
}

# Example usage:
# SERVER_OUTPUT="[INFO] Server started on PID 1885662"
# PID=$(get_pid_from_output "$SERVER_OUTPUT")
# echo "$PID"  # 1885662

# Extracts the message from server output supporting:
#   [SUCCESS] Received message from PID xxxxxxx: 'message'
#   xxxxxxxx : <message>
#   xxxxxxxx = <message>
#   <message>
# Helper: Strip only matching leading/trailing single or double quotes
strip_quotes() {
    local s="$1"
    # If string starts and ends with the same quote (single or double), remove both
    if [[ "$s" =~ ^\'(.*)\'$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$s" =~ ^\"(.*)\"$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$s"
    fi
}

get_message_from_output() {
    local output="$1"
    local msg

    # Try to match [SUCCESS] Received message from PID ...: 'message'
    # Accepts embedded quotes inside the message
    msg=$(echo "$output" | sed -n -E "s/^\[SUCCESS\] Received message from PID [0-9]+: ('.*'|\".*\")$/\1/p" | tail -n 1)
    if [[ -n "$msg" ]]; then
        strip_quotes "$msg"
        return
    fi

    # Try to match 'xxxx : <message>' or 'xxxx = <message>'
    msg=$(echo "$output" | sed -n -E 's/^[^:=]+[:=][[:space:]]*(.*)$/\1/p' | tail -n 1)
    if [[ -n "$msg" ]]; then
        strip_quotes "$msg"
        return
    fi

    # Fallback: just return the last non-empty line
    msg=$(echo "$output" | grep -v '^\s*$' | tail -n 1)
    strip_quotes "$msg"
}