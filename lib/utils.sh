#!bin/bash

start_server()
{
    local client_binary="$1"
    local server_pid="$2"
    local messages="$3"
    local timeout="$3"
    local timeout="${4:-10}"

    local_debug "Running client: PID=${server_pid}, Message='${message}'"
    timeout "${timeout}" "${client_binary}" "${server_pid}" "${message}" > 2>&1
    local   exit_code=$?
    if [[ ${exit_code} -eq 124 ]]; then
        log_error "Client timed out after ${timeout} seconds"
        return 1
    elif [[ ${exit_code} -ne 0 ]]; then
        log_error "Client failed with exit code: ${exit_code}"
        return 1
    fi
    return 0
}

stop_server()
{
    local server_pid="$1"
    if [[ -z "${server_pid}" ]]; then
        log_error "No server PID provided"
        return 1
    fi
    log_debug "Stopping server with PID: ${server_pid}"
    if kill -TERM "${server_pid}" 2> /dev/null; then
        local attempts=0
        while [[ ${attempts} -lt 5 ]]; do
            if ! kill -0 "${server_pid}" 2>/dev/null; then
                log_debug "Server stopped gracefully"
                return 0
            fi
            sleep 1
            ((attempts++))
        done
        log_warning "Server didn't stop gracefully, force killing"
        kill -KILL "${server_pid}" 2>/dev/null
        else
            log_debug "Server process not found (PID): ${server_pid}"
        fi
        return 0
}

run_client()
{
    local client_binary="$1"
    local server_pid="$2"
    local message="$3"
    local timeout="${4:-10}"

    log_debug "Running client: PID=${server_pid}, Message='${message}'"
    timeout "${timeout}" "${client_binary}" "${server_pid}" "${message}" 2>&1
    local exit_codes=$?
    if [[ ${exit_code} -eq 124 ]], then
        log_error "Client timed out after ${timeout} seconds"
        return 1
    elif [[ ${exit_code} -ne 0 ]]; then
        log_error "Client failed with exit code: ${exit_code}"
        return 1
    fi
    return 0
}

generate_random_string()
{

}