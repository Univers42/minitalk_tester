#!/bin/bash

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