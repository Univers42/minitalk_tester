#!/bin/bash

clean_results()
{
	if [[ -d "$RESULTS_DIR" ]]; then
		log_info "Cleaning previous results..."
		rm -rf "${RESULTS_DIR}"
		log_success "Result cleaned"
	fi
}

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

message() {
    local custom_message="$1"
    # Start server
    start_server
    local PID_SERVER=$(get_pid)
    # Run client with custom message
    run_client "${PID_SERVER}" "${custom_message}"
    # Check server output
    if [[ -s /tmp/server_output.log ]]; then
        local RECEIVED_MSG
        # Extract only the last occurrence of the received message
        RECEIVED_MSG=$(awk '
            match($0, /^Received message: /) {
                msg = substr($0, RSTART + RLENGTH)
            }
            match($0, /^Received: /) {
                msg = substr($0, RSTART + RLENGTH)
            }
            END { if (msg) print msg }
        ' /tmp/server_output.log)
        RECEIVED_MSG="${RECEIVED_MSG%$'\n'}"
        if [[ "$RECEIVED_MSG" == "$custom_message" ]]; then
            log_success "Server received the correct message: '$RECEIVED_MSG'"
        else
            log_error "Server did not receive the correct message. Got: '$RECEIVED_MSG', expected: '$custom_message'"
        fi
    else
        log_warning "No server output found or server did not print the message."
    fi
    stop_server
}


