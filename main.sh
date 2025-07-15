#!/bin/bash
trap 'echo "SIGINT received, ignoring...";' SIGINT

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

    # Performance mode variables
    local perf_count=0
    local perf_total_time=0
    local perf_total_chars=0

    if [[ ! -f "$messages_file" ]]; then
        log_error "Messages file not found: $messages_file"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
        ((total++))
        log_info "Testing message: '$line'"

        # --- Clear server output log before each test ---
        : > /tmp/server_output.log

        # --- Start server for each test ---
        start_server
        local PID_SERVER=$(get_pid)

        # --- Wait for server to be ready ---
        sleep 0.05

        if [[ "$PERFORMANCE_MODE" == true && ${#line} -gt 100 ]]; then
            local start_time=$(date +%s.%N)
            run_client "${PID_SERVER}" "$line"
            local end_time=$(date +%s.%N)
            # Calculate elapsed time in seconds (float)
            local elapsed=$(echo "$end_time - $start_time" | bc)
            perf_total_time=$(echo "$perf_total_time + $elapsed" | bc)
            perf_total_chars=$(echo "$perf_total_chars + ${#line}" | bc)
            ((perf_count++))
        else
            run_client "${PID_SERVER}" "$line"
        fi

        # --- Wait a moment for server to print output ---
        sleep 0.05

        # Only check server output if the output file exists and is not empty
        if [[ -s /tmp/server_output.log ]]; then
            local RECEIVED_MSG
            RECEIVED_MSG=$(get_message_from_output "$(cat /tmp/server_output.log)")
            RECEIVED_MSG="${RECEIVED_MSG%$'\n'}"
            if [[ "$RECEIVED_MSG" == "$line" ]]; then
                log_success "Server received the correct message: '$RECEIVED_MSG'"
                ((passed++))
            else
                log_error "Server did not receive the correct message. Got: '$RECEIVED_MSG', expected: '$line'"
                ((failed++))
            fi
        else
            log_error "Server did not receive the correct message. Got: '', expected: '$line'"
            ((failed++))
        fi

        # --- Stop server after each test ---
        stop_server

    done < "$messages_file"

    log_section "tester_minitalk summary"
    log_info "Total messages: $total"
    log_success "Passed: $passed"
    if [[ $failed -gt 0 ]]; then
        log_error "Failed: $failed"
    fi

    if [[ "$PERFORMANCE_MODE" == true && $perf_count -gt 0 ]]; then
        local avg_time=$(echo "scale=6; $perf_total_time / $perf_count" | bc)
        local avg_chars=$(echo "scale=2; $perf_total_chars / $perf_count" | bc)
        log_info "Performance: Average time for messages >100 chars: ${avg_time}s over $perf_count messages"
        log_info "Performance: Average characters per message >100 chars: ${avg_chars}"
        log_info "Performance: Average time per character: $(echo "scale=8; $avg_time / $avg_chars" | bc)s"
    fi
}

start_server()
{
    # Ignore SIGINT in the subshell so the server doesn't get killed
    (
        trap '' SIGINT
        ./${SERVER_BIN} > /tmp/server_output.log 2>&1 &
        echo $! > "$PID_FILE"
    )
    sleep ${AWAIT_SERVER}
    SERVER_PID=$(get_pid)
    if [[ -z "$SERVER_PID" ]]; then
        log_error "Could not retrieve server PID"
        kill "$SERVER_BG_PID" 2>/dev/null
        exit 1
    fi
    log_info "Started server with PID $SERVER_PID"
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
		# Use the parser function to extract the message
		RECEIVED_MSG=$(get_message_from_output "$(cat /tmp/server_output.log)")
		RECEIVED_MSG="${RECEIVED_MSG%$'\n'}"
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