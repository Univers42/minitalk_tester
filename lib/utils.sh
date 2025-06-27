#!bin/bash

AWAIT_SERVER=0.01
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
    sleep ${AWAIT_SERVER}
    # Use robust get_pid to extract the PID
    SERVER_PID=$(get_pid)
    if [[ -z "$SERVER_PID" ]]; then
        log_error "Could not retrieve server PID"
        kill "$SERVER_BG_PID" 2>/dev/null
        exit 1
    fi
    echo $SERVER_PID > "$PID_FILE"
    log_info "Started server with PID $SERVER_PID"
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

get_pid()
{
    # Try to find a PID in the server output, robust to various formats
    # Handles: PID: 1234, pid: 1234, PID = 1234, Server PID: 1234, etc.
    local pid_line
    pid_line=$(grep -iE 'pid[[:space:]]*[:=][[:space:]]*[0-9]+' /tmp/server_output.log | head -n1)
    if [[ -z "$pid_line" ]]; then
        # Try to find a line with just a number (fallback)
        pid_line=$(grep -E '^[[:space:]]*[0-9]+[[:space:]]*$' /tmp/server_output.log | head -n1)
    fi
    local pid
    pid=$(echo "$pid_line" | grep -oE '[0-9]+')
    echo "$pid"
}