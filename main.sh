#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/config/constants.sh"
source "${SCRIPT_DIR}/config/colors.sh"
source "${SCRIPT_DIR}/config/settings.conf"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/parser.sh"
source "${SCRIPT_DIR}/lib/commands.sh"
source "${SCRIPT_DIR}/lib/leaks.sh"

set_log_level info

setup_environment()
{
    mkdir -p "${RESULTS_DIR}"
}

tester_minitalk()
{
    local messages_file="${SCRIPT_DIR}/config/messages.conf"
    local total=0
    local passed=0
    local failed=0

    if [[ ! -f "$messages_file" ]]; then
        log_error "Messages file not found: $messages_file"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        ((total++))
        log_info "Testing message: '$line'"
        # Use the message function to test
        message "$line"
        # Check last log for success/failure
        if tail -n 5 "${LOG_FILE}" | grep -q "Server received the correct message"; then
            ((passed++))
        else
            ((failed++))
        fi
    done < "$messages_file"

    log_section "tester_minitalk summary"
    log_info "Total messages: $total"
    log_success "Passed: $passed"
    if [[ $failed -gt 0 ]]; then
        log_error "Failed: $failed"
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
		clean_results
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

	# If a custom message is requested, run the message command and exit
	if [[ -n "$MESSAGE" && "$MESSAGE" != "just a message" ]]; then
		message "$MESSAGE"
		exit 0
	fi

	# Only run the main test if not cleaning or custom message
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
		# Try both "Received message: ..." and "Received: ..." patterns
		RECEIVED_MSG=$(grep -oP 'Received message: \K.*' /tmp/server_output.log | head -n1)
		if [[ -z "$RECEIVED_MSG" ]]; then
			RECEIVED_MSG=$(grep -oP 'Received: \K.*' /tmp/server_output.log | head -n1)
		fi
		if [[ "$RECEIVED_MSG" == "$MESSAGE" ]]; then
			log_success "Server received the correct message: '$RECEIVED_MSG'"
		else
			log_error "Server did not receive the correct message. Got: '$RECEIVED_MSG', expected: '$MESSAGE'"
		fi
	else
		log_warning "No server output found or server did not print the message."
	fi

	# Add tester_minitalk command
	if [[ "$RUN_TESTER_MINITALK" == true ]]; then
        tester_minitalk
        exit 0
    fi

	stop_server
}

main "$@"