#!/bin/bash

# =============================================================================
# ENHANCED PERFORMANCE TESTS SUITE
# =============================================================================
# Tests for performance, throughput, and stress scenarios using messages.conf
# =============================================================================

PERF_TOTAL=0
PERF_PASSED=0
PERF_FAILED=0

# Configuration
MESSAGES_CONF="${SCRIPT_DIR}/config/messages.conf"
SERVER_START_DELAY=${SERVER_START_DELAY:-2}
CLIENT_TIMEOUT=${CLIENT_TIMEOUT:-10}
PERFORMANCE_THRESHOLD_MS=${PERFORMANCE_THRESHOLD_MS:-1000}  # 1 second threshold

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Read messages from config file, filtering out comments and empty lines
read_test_messages() {
    local messages=()
    
    if [[ ! -f "${MESSAGES_CONF}" ]]; then
        log_error "Messages config file not found: ${MESSAGES_CONF}"
        return 1
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments (lines starting with #) and empty lines
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "${line// }" ]]; then
            messages+=("$line")
        fi
    done < "${MESSAGES_CONF}"
    
    # Return messages as array
    printf '%s\n' "${messages[@]}"
}

# Start server and return PID
start_test_server() {
    local server_output_file="$1"
    
    log_debug "Starting server: ${SERVER_BINARY}"
    "${SERVER_BINARY}" > "${server_output_file}" 2>&1 &
    local server_pid=$!
    
    # Wait for server to start
    sleep "${SERVER_START_DELAY}"
    
    # Check if server is still running
    if ! kill -0 "${server_pid}" 2>/dev/null; then
        log_error "Server failed to start or crashed immediately"
        return 1
    fi
    
    # Extract PID from server output if needed
    local displayed_pid
    if [[ -f "${server_output_file}" ]]; then
        displayed_pid=$(grep -o 'PID: [0-9]*' "${server_output_file}" | head -1 | cut -d' ' -f2)
        if [[ -n "${displayed_pid}" ]]; then
            echo "${displayed_pid}"
        else
            echo "${server_pid}"
        fi
    else
        echo "${server_pid}"
    fi
}

# Stop server by PID
stop_test_server() {
    local server_pid="$1"
    
    if [[ -n "${server_pid}" ]] && kill -0 "${server_pid}" 2>/dev/null; then
        log_debug "Stopping server (PID: ${server_pid})"
        kill -TERM "${server_pid}" 2>/dev/null
        sleep 1
        
        # Force kill if still running
        if kill -0 "${server_pid}" 2>/dev/null; then
            kill -9 "${server_pid}" 2>/dev/null
        fi
    fi
}

# Measure time in milliseconds
get_time_ms() {
    date +%s%3N
}

# Send message and measure performance
send_message_timed() {
    local server_pid="$1"
    local message="$2"
    local output_file="$3"
    
    local start_time=$(get_time_ms)
    
    # Send message using client
    if timeout "${CLIENT_TIMEOUT}" "${CLIENT_BINARY}" "${server_pid}" "${message}" > "${output_file}" 2>&1; then
        local end_time=$(get_time_ms)
        local duration=$((end_time - start_time))
        echo "${duration}"
        return 0
    else
        local end_time=$(get_time_ms)
        local duration=$((end_time - start_time))
        echo "${duration}"
        return 1
    fi
}

# =============================================================================
# PERFORMANCE TEST FUNCTIONS
# =============================================================================

# Test individual message performance
performance_individual_messages_test() {
    local temp_dir="$1"
    local test_name="Individual Message Performance"
    
    log_debug "Running: ${test_name}"
    
    local server_output="${temp_dir}/server_individual.out"
    local client_output="${temp_dir}/client_individual.out"
    local results_file="${temp_dir}/individual_results.txt"
    
    # Start server
    local server_pid
    server_pid=$(start_test_server "${server_output}")
    if [[ $? -ne 0 ]]; then
        log_test_result "${test_name}" "FAIL" "Failed to start server"
        return 1
    fi
    
    local total_messages=0
    local successful_messages=0
    local total_time=0
    local max_time=0
    local min_time=999999
    
    # Read and test each message
    while IFS= read -r message; do
        ((total_messages++))
        
        local duration
        duration=$(send_message_timed "${server_pid}" "${message}" "${client_output}")
        local send_result=$?
        
        if [[ ${send_result} -eq 0 ]]; then
            ((successful_messages++))
            total_time=$((total_time + duration))
            
            # Track min/max times
            if [[ ${duration} -gt ${max_time} ]]; then
                max_time=${duration}
            fi
            if [[ ${duration} -lt ${min_time} ]]; then
                min_time=${duration}
            fi
            
            # Log individual result
            echo "Message ${total_messages}: ${duration}ms - SUCCESS" >> "${results_file}"
            
            # Check if message exceeds threshold
            if [[ ${duration} -gt ${PERFORMANCE_THRESHOLD_MS} ]]; then
                log_warning "Message ${total_messages} took ${duration}ms (threshold: ${PERFORMANCE_THRESHOLD_MS}ms)"
            fi
        else
            echo "Message ${total_messages}: ${duration}ms - FAILED" >> "${results_file}"
            log_debug "Message ${total_messages} failed to send"
        fi
        
        # Brief pause between messages
        sleep 0.1
        
    done < <(read_test_messages)
    
    stop_test_server "${server_pid}"
    
    # Calculate statistics
    local success_rate=0
    local avg_time=0
    
    if [[ ${total_messages} -gt 0 ]]; then
        success_rate=$(( (successful_messages * 100) / total_messages ))
    fi
    
    if [[ ${successful_messages} -gt 0 ]]; then
        avg_time=$((total_time / successful_messages))
    fi
    
    # Generate summary
    local summary="Total: ${total_messages}, Success: ${successful_messages} (${success_rate}%), Avg: ${avg_time}ms, Min: ${min_time}ms, Max: ${max_time}ms"
    echo "=== INDIVIDUAL MESSAGE PERFORMANCE SUMMARY ===" >> "${results_file}"
    echo "${summary}" >> "${results_file}"
    
    log_debug "${summary}"
    
    # Test passes if success rate >= 95% and average time <= threshold
    if [[ ${success_rate} -ge 95 ]] && [[ ${avg_time} -le ${PERFORMANCE_THRESHOLD_MS} ]]; then
        log_test_result "${test_name}" "PASS" "${summary}"
        return 0
    else
        log_test_result "${test_name}" "FAIL" "${summary}"
        return 1
    fi
}

# Test throughput with rapid message sending
performance_throughput_test() {
    local temp_dir="$1"
    local test_name="Message Throughput Test"
    
    log_debug "Running: ${test_name}"
    
    local server_output="${temp_dir}/server_throughput.out"
    local client_output="${temp_dir}/client_throughput.out"
    local results_file="${temp_dir}/throughput_results.txt"
    
    # Start server
    local server_pid
    server_pid=$(start_test_server "${server_output}")
    if [[ $? -ne 0 ]]; then
        log_test_result "${test_name}" "FAIL" "Failed to start server"
        return 1
    fi
    
    # Read all messages into array for rapid sending
    local messages=()
    while IFS= read -r message; do
        messages+=("$message")
    done < <(read_test_messages)
    
    local total_messages=${#messages[@]}
    local successful_messages=0
    local start_time=$(get_time_ms)
    
    # Send all messages rapidly
    for message in "${messages[@]}"; do
        if timeout "${CLIENT_TIMEOUT}" "${CLIENT_BINARY}" "${server_pid}" "${message}" >> "${client_output}" 2>&1; then
            ((successful_messages++))
        fi
        # No delay between messages for throughput test
    done
    
    local end_time=$(get_time_ms)
    local total_duration=$((end_time - start_time))
    
    stop_test_server "${server_pid}"
    
    # Calculate throughput
    local success_rate=0
    local throughput=0
    
    if [[ ${total_messages} -gt 0 ]]; then
        success_rate=$(( (successful_messages * 100) / total_messages ))
    fi
    
    if [[ ${total_duration} -gt 0 ]]; then
        throughput=$(( (successful_messages * 1000) / total_duration ))  # messages per second
    fi
    
    local summary="Messages: ${successful_messages}/${total_messages} (${success_rate}%), Time: ${total_duration}ms, Throughput: ${throughput} msg/sec"
    echo "=== THROUGHPUT TEST SUMMARY ===" >> "${results_file}"
    echo "${summary}" >> "${results_file}"
    
    log_debug "${summary}"
    
    # Test passes if success rate >= 90% and throughput >= 1 msg/sec
    if [[ ${success_rate} -ge 90 ]] && [[ ${throughput} -ge 1 ]]; then
        log_test_result "${test_name}" "PASS" "${summary}"
        return 0
    else
        log_test_result "${test_name}" "FAIL" "${summary}"
        return 1
    fi
}

# Test with different message sizes
performance_message_size_test() {
    local temp_dir="$1"
    local test_name="Message Size Performance Test"
    
    log_debug "Running: ${test_name}"
    
    local server_output="${temp_dir}/server_size.out"
    local client_output="${temp_dir}/client_size.out"
    local results_file="${temp_dir}/size_results.txt"
    
    # Start server
    local server_pid
    server_pid=$(start_test_server "${server_output}")
    if [[ $? -ne 0 ]]; then
        log_test_result "${test_name}" "FAIL" "Failed to start server"
        return 1
    fi
    
    # Categorize messages by length and test each category
    local short_messages=()
    local medium_messages=()
    local long_messages=()
    
    while IFS= read -r message; do
        local length=${#message}
        if [[ ${length} -le 10 ]]; then
            short_messages+=("$message")
        elif [[ ${length} -le 50 ]]; then
            medium_messages+=("$message")
        else
            long_messages+=("$message")
        fi
    done < <(read_test_messages)
    
    # Test each category
    local categories=("short" "medium" "long")
    local all_passed=true
    
    for category in "${categories[@]}"; do
        local messages_ref="${category}_messages[@]"
        local messages=("${!messages_ref}")
        
        if [[ ${#messages[@]} -eq 0 ]]; then
            echo "No ${category} messages found, skipping..." >> "${results_file}"
            continue
        fi
        
        local successful=0
        local total_time=0
        
        for message in "${messages[@]}"; do
            local duration
            duration=$(send_message_timed "${server_pid}" "${message}" "${client_output}")
            if [[ $? -eq 0 ]]; then
                ((successful++))
                total_time=$((total_time + duration))
            fi
            sleep 0.1
        done
        
        local avg_time=0
        if [[ ${successful} -gt 0 ]]; then
            avg_time=$((total_time / successful))
        fi
        
        local category_summary="${category}: ${successful}/${#messages[@]} messages, avg ${avg_time}ms"
        echo "${category_summary}" >> "${results_file}"
        log_debug "${category_summary}"
        
        # Check if this category performance is acceptable
        if [[ ${successful} -lt ${#messages[@]} ]] || [[ ${avg_time} -gt ${PERFORMANCE_THRESHOLD_MS} ]]; then
            all_passed=false
        fi
    done
    
    stop_test_server "${server_pid}"
    
    if [[ ${all_passed} == true ]]; then
        log_test_result "${test_name}" "PASS" "All message size categories performed within limits"
        return 0
    else
        log_test_result "${test_name}" "FAIL" "Some message size categories failed performance requirements"
        return 1
    fi
}

# Stress test with repeated message sending
performance_stress_test() {
    local temp_dir="$1"
    local test_name="Stress Test"
    
    log_debug "Running: ${test_name}"
    
    local server_output="${temp_dir}/server_stress.out"
    local client_output="${temp_dir}/client_stress.out"
    local results_file="${temp_dir}/stress_results.txt"
    
    # Start server
    local server_pid
    server_pid=$(start_test_server "${server_output}")
    if [[ $? -ne 0 ]]; then
        log_test_result "${test_name}" "FAIL" "Failed to start server"
        return 1
    fi
    
    # Get first few messages for stress testing
    local stress_messages=()
    local count=0
    while IFS= read -r message && [[ ${count} -lt 5 ]]; do
        stress_messages+=("$message")
        ((count++))
    done < <(read_test_messages)
    
    if [[ ${#stress_messages[@]} -eq 0 ]]; then
        log_test_result "${test_name}" "FAIL" "No messages available for stress test"
        stop_test_server "${server_pid}"
        return 1
    fi
    
    local total_attempts=0
    local successful_sends=0
    local iterations=20  # Send each message 20 times
    
    for iteration in $(seq 1 ${iterations}); do
        for message in "${stress_messages[@]}"; do
            ((total_attempts++))
            
            if timeout "${CLIENT_TIMEOUT}" "${CLIENT_BINARY}" "${server_pid}" "${message}" >> "${client_output}" 2>&1; then
                ((successful_sends++))
            fi
            
            # Very brief pause to avoid overwhelming
            sleep 0.05
        done
        
        # Show progress
        if [[ $((iteration % 5)) -eq 0 ]]; then
            log_debug "Stress test progress: ${iteration}/${iterations} iterations"
        fi
    done
    
    stop_test_server "${server_pid}"
    
    local success_rate=0
    if [[ ${total_attempts} -gt 0 ]]; then
        success_rate=$(( (successful_sends * 100) / total_attempts ))
    fi
    
    local summary="Stress test: ${successful_sends}/${total_attempts} (${success_rate}%) over ${iterations} iterations"
    echo "=== STRESS TEST SUMMARY ===" >> "${results_file}"
    echo "${summary}" >> "${results_file}"
    
    log_debug "${summary}"
    
    # Test passes if success rate >= 90%
    if [[ ${success_rate} -ge 90 ]]; then
        log_test_result "${test_name}" "PASS" "${summary}"
        return 0
    else
        log_test_result "${test_name}" "FAIL" "${summary}"
        return 1
    fi
}

# =============================================================================
# MAIN PERFORMANCE TEST RUNNER
# =============================================================================

run_performance_tests() {
    log_section "Performance Tests" "${BOLD_MAGENTA}"
    
    local temp_dir="${RESULTS_DIR}/perf_temp"
    mkdir -p "${temp_dir}"
    
    # Reset counters
    PERF_TOTAL=0
    PERF_PASSED=0
    PERF_FAILED=0
    
    # Check if messages config exists
    if [[ ! -f "${MESSAGES_CONF}" ]]; then
        log_error "Messages configuration file not found: ${MESSAGES_CONF}"
        return 1
    fi
    
    # Count available test messages
    local message_count
    message_count=$(read_test_messages | wc -l)
    log_info "Found ${message_count} test messages in configuration"
    
    if [[ ${message_count} -eq 0 ]]; then
        log_error "No valid test messages found in configuration file"
        return 1
    fi
    
    # Define test functions
    local tests=(
        "performance_individual_messages_test"
        "performance_throughput_test"
        "performance_message_size_test"
        "performance_stress_test"
    )
    
    # Run each test
    for test_func in "${tests[@]}"; do
        ((PERF_TOTAL++))
        log_progress "${PERF_TOTAL}" "${#tests[@]}" "Running performance tests"
        
        if ${test_func} "${temp_dir}"; then
            ((PERF_PASSED++))
        else
            ((PERF_FAILED++))
        fi
        
        # Brief pause between tests
        sleep 1
    done
    
    # Performance test summary
    log_section "Performance Test Results" "${BOLD_MAGENTA}"
    echo -e "${BOLD}Performance Tests Completed:${RESET}"
    echo -e "  Total: ${PERF_TOTAL}"
    echo -e "  ${GREEN}Passed: ${PERF_PASSED}${RESET}"
    echo -e "  ${RED}Failed: ${PERF_FAILED}${RESET}"
}

# Initialize performance tests if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    log_debug "Enhanced performance tests module loaded"
fi