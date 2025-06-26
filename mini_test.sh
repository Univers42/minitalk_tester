#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/logger.sh"

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

check_valgrind_leaks()
{
    local bin="$1"
    shift
    local valgrind_log="/tmp/valgrind_output.log"
    local valgrind_save="/tmp/valgrind_$(basename "$bin").log"

    if ! command -v valgrind >/dev/null 2>&1; then
        log_warning "Valgrind is not installed, skipping leak check."
        return
    fi

    valgrind --leak-check=full --track-origins=yes --error-exitcode=42 "$bin" "$@" > /dev/null 2> "$valgrind_log"

    # Check for leaks summary
    local leaks_found=0
    if grep -q "definitely lost: [^0]" "$valgrind_log"; then
        log_error "Memory leaks detected by valgrind in $bin:"
        grep "definitely lost:" "$valgrind_log" | log_error
        grep "indirectly lost:" "$valgrind_log" | log_error
        grep "LEAK SUMMARY:" -A 5 "$valgrind_log" | log_error
        leaks_found=1
    fi

    # Check for any errors (not just leaks)
    if grep -q "ERROR SUMMARY: [1-9][0-9]* errors" "$valgrind_log"; then
        log_error "Valgrind detected errors in $bin:"
        grep "ERROR SUMMARY:" "$valgrind_log" | log_error
        # Optionally, print the relevant error lines:
        grep -A 5 "ERROR SUMMARY:" "$valgrind_log" | log_error
        leaks_found=1
    fi

    if [[ $leaks_found -eq 0 ]]; then
        log_info "Valgrind found no memory leaks or errors in $bin."
    else
        cp "$valgrind_log" "$valgrind_save"
        log_info "Full valgrind log saved to $valgrind_save"
    fi
}

main()
{
    local MESSAGE="${1:-just a message}"

    start_server 
    local PID_SERVER=$(get_pid)
    run_client "${PID_SERVER}" "${MESSAGE}"

    # Pass arguments as separate parameters
    check_valgrind_leaks "${CLIENT_BIN}" "${PID_SERVER}" "${MESSAGE}"

    # Check server output for the received message
    local RECEIVED_MSG
    RECEIVED_MSG=$(grep -oP 'Received message: \K.*' /tmp/server_output.log | head -n1)
    if [[ "$RECEIVED_MSG" == "$MESSAGE" ]]; then
        log_success "Server received the correct message: '$RECEIVED_MSG'"
    else
        log_error "Server did not receive the correct message. Got: '$RECEIVED_MSG', expected: '$MESSAGE'"
    fi

    stop_server
}

main "$@"