#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/logger.sh"
RESULTS_DIR="logs"
show_usage()
{
	echo -e "${BLUE}${BOLD}Minitalk Tester${RESET}"
	echo -e "${CYAN}Usage: $0 [options]${RESET}"
	echo
	echo -e "${YELLOW}Options:${RESET}"
	echo -e "   -h, --help			Show this help message"
	echo -e "   -v, --verbose		Enable verbose output"
	echo -e "   -q, --quiet			Quiet mode (minimal output)"
	echo -e "   -b, --basic			run basic tests only"
	echo -e "   -e, --edge			Run edge case tests only"
	echo -e "   -p, --performance	Run performance tests only"
	echo -e "   -a, --all			Run  all tests (default)"
	echo -e "	-c, --clean			Clean previous results"
    echo -e "   -m, --message       custom the message test"
	echo -e "   --server-path		Custom server binary path"
	echo -e "   --client-path		Custom client binary path"
	echo
	echo -e "${GREEN}Examples:${RESET}"
	echo -e "  $0                  # Run all tests"
	echo -e "  $0 -b -v            # Run basic tests with verbose output"
	echo -e "  $0 --clean          # Clean results and exit"
}


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
			*)
				log_error "unknown option: $1"
				SHOW_USAGE=true
				shift
				;;
		esac
	done
}

set_log_level info

SERVER_BIN="../server"
CLIENT_BIN="../client"
PID_FILE="server.pid"

run_client()
{
    local pid_server="$1"
    local message="$2"

    if [[ ! -f ${CLIENT_BIN} ]]; then
        log_error "The file is not found, please compile the minitalk project before"
        exit 1
    fi
    CLIENT_OUTPUT=$(${CLIENT_BIN} "${pid_server}" "${message}" 2>&1)
    CLIENT_STATUS=$?
    if [[ $CLIENT_STATUS -eq 0 ]]; then
        log_success "Client ran successfully"
    else
        log_error "Client failed with status $CLIENT_STATUS"
        log_error "Client output: $CLIENT_OUTPUT"
    fi
}

stop_server()
{
    if [[ -f "$PID_FILE" ]]; then
        SERVER_PID=$(cat "$PID_FILE")
        kill -TERM "$SERVER_PID" 2>/dev/null
        rm -f "$PID_FILE"
        log_info "Stopped server with PID $SERVER_PID"
    else
        log_warning "No PID file found. Server may not be running."
    fi
}


start_server()
{
    if [[ ! -x ${SERVER_BIN} ]]; then
        log_error "the server bin is not executable"
        exit 1
    fi
    # Start the server in the background, redirect output to a file
    ./${SERVER_BIN} > /tmp/server_output.log 2>&1 &
    SERVER_BG_PID=$!
    # Wait a moment for the server to print its PID
    sleep 0.2
    # Extract the PID from the output
    SERVER_PID=$(grep -m1 "Server PID:" /tmp/server_output.log | awk '{print $3}')
    if [[ -z "$SERVER_PID" ]]; then
        log_error "Could not retrieve server PID"
        kill "$SERVER_BG_PID" 2>/dev/null
        exit 1
    fi
    echo $SERVER_PID > "$PID_FILE"
    log_info "Started server with PID $SERVER_PID"
}

get_pid()
{
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE"
    else
        echo ""
    fi
}

run_valgrind()
{
    local bin="$1"
    shift
    local valgrind_log="$1"
    shift

    if ! command -v valgrind >/dev/null 2>&1; then
        log_warning "Valgrind is not installed, skipping leak check."
        return 1
    fi

    valgrind --leak-check=full --track-origins=yes --error-exitcode=42 "$bin" "$@" > /dev/null 2> "$valgrind_log"
}

parse_valgrind_log()
{
    local valgrind_log="$1"
    local bin_name="$2"
    # Always copy the log to the current directory, even if no errors
    local valgrind_save="./valgrind_${bin_name}.log"
    cp "$valgrind_log" "$valgrind_save" 2>/dev/null

    local leaks_found=0

    if grep -q "definitely lost: [^0]" "$valgrind_log"; then
        leaks_found=1
    fi

    if grep -q "ERROR SUMMARY: [1-9][0-9]* errors" "$valgrind_log"; then
        leaks_found=1
    fi

    # Check for still reachable memory
    local still_reachable
    still_reachable=$(grep "still reachable:" "$valgrind_log" | grep -v "0 bytes in 0 blocks")
    if [[ -n "$still_reachable" ]]; then
        log_warning "Valgrind: still reachable memory detected in $bin_name:"
        while IFS= read -r line; do
            [[ -n "$line" ]] && log_warning "$line"
        done <<< "$still_reachable"
    fi

    if [[ $leaks_found -eq 0 && -z "$still_reachable" ]]; then
        log_info "Valgrind found no memory leaks or errors in $bin_name."
        log_info "Valgrind log for $bin_name saved at: $valgrind_save"
        return 0
    else
        log_error "Valgrind found memory leaks or errors in $bin_name. See $valgrind_save for details."
        log_info "---- Valgrind error summary for $bin_name ----"
        grep "definitely lost:" "$valgrind_log" | log_error
        grep "indirectly lost:" "$valgrind_log" | log_error
        if [[ -n "$still_reachable" ]]; then
            while IFS= read -r line; do
                [[ -n "$line" ]] && log_warning "$line"
            done <<< "$still_reachable"
        fi
        grep "LEAK SUMMARY:" -A 5 "$valgrind_log" | log_error
        grep "ERROR SUMMARY:" "$valgrind_log" | log_error
        grep -A 5 "ERROR SUMMARY:" "$valgrind_log" | log_error
        log_info "---------------------------------------------"
        log_info "Valgrind log for $bin_name saved at: $valgrind_save"
        return 1
    fi
}

check_valgrind_leaks()
{
    local bin="$1"
    shift
    local valgrind_log="/tmp/valgrind_$(basename "$bin").log"
    run_valgrind "$bin" "$valgrind_log" "$@"
    if parse_valgrind_log "$valgrind_log" "$(basename "$bin")"; then
        log_success "Valgrind check passed for $(basename "$bin")"
    else
        log_error "Valgrind check failed for $(basename "$bin")"
    fi
}

check_server_valgrind()
{
    local valgrind_log="/tmp/valgrind_server.log"
    local valgrind_save="./valgrind_server.log"
    run_valgrind "${SERVER_BIN}" "$valgrind_log" &
    local valgrind_pid=$!
    sleep 0.2
    # Send SIGINT for graceful shutdown, then SIGKILL if still running
    kill -INT "$valgrind_pid" 2>/dev/null
    # Wait up to 2 seconds for graceful exit
    for i in {1..20}; do
        if ! kill -0 "$valgrind_pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    # If still running, force kill
    if kill -0 "$valgrind_pid" 2>/dev/null; then
        kill -KILL "$valgrind_pid" 2>/dev/null
        wait "$valgrind_pid" 2>/dev/null
        log_warning "Server did not exit gracefully under valgrind, killed forcibly."
    else
        wait "$valgrind_pid" 2>/dev/null
    fi

    cp "$valgrind_log" "$valgrind_save" 2>/dev/null

    if parse_valgrind_log "$valgrind_log" "server"; then
        log_success "Valgrind check passed for server"
    else
        log_error "Valgrind check failed for server"
    fi
    log_info "Valgrind log for server saved at: $valgrind_save"
}

setup_environment()
{
    mkdir -p "${RESULTS_DIR}"
}

clean_results()
{
	if [[-d "$RESULTS_DIR" ]]; then
		log_info "Cleaning previous results..."
		rm -rf "${RESULTS_DIR}"
		log_success "Result cleaned"
	fi
}

main()
{
	parse_arguments "$@"

	# If help or verbose flag was passed, show usage and exit
	if [[ "$SHOW_USAGE" == true ]]; then
		show_usage
		exit 0
	fi

	# Handle clean only BEFORE setup_environment
	if [[ "$CLEAN_ONLY" == true ]]; then
		log_info "Cleaning previous results..."
		rm -f ./valgrind_client.log ./valgrind_server.log /tmp/valgrind_client.log /tmp/valgrind_server.log /tmp/server_output.log server.pid minitalk.log
		if [[ -d "$RESULTS_DIR" ]]; then
			rm -rf "$RESULTS_DIR"
		fi
		log_success "Clean complete."
		exit 0
	fi

    setup_environment

	# Override binaries if custom paths are provided
	if [[ -n "$SERVER_BINARY" ]]; then
		SERVER_BIN="$SERVER_BINARY"
	fi
	if [[ -n "$CLIENT_BINARY" ]]; then
		CLIENT_BIN="$CLIENT_BINARY"
	fi

	# Only run the main test if not cleaning
	start_server 
	local PID_SERVER=$(get_pid)
	run_client "${PID_SERVER}" "${MESSAGE}"

	# Check valgrind leaks for the client
	check_valgrind_leaks "${CLIENT_BIN}" "${PID_SERVER}" "${MESSAGE}"

	# Check valgrind leaks for the server (runs a new instance under valgrind)
	check_server_valgrind

	# Only check server output if the output file exists and is not empty
	if [[ -s /tmp/server_output.log ]]; then
		local RECEIVED_MSG
		RECEIVED_MSG=$(grep -oP 'Received message: \K.*' /tmp/server_output.log | head -n1)
		if [[ "$RECEIVED_MSG" == "$MESSAGE" ]]; then
			log_success "Server received the correct message: '$RECEIVED_MSG'"
		else
			log_error "Server did not receive the correct message. Got: '$RECEIVED_MSG', expected: '$MESSAGE'"
		fi
	else
		log_warning "No server output found or server did not print the message."
	fi

	stop_server
}

main "$@"