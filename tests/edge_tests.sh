#!/bin/bash

# =============================================================================
# EDGE CASE TESTS SUITE
# =============================================================================
# Tests for edge cases, error conditions, and boundary scenarios
# =============================================================================

# Test suite counters
EDGE_TOTAL=0
EDGE_PASSED=0
EDGE_FAILED=0

# =============================================================================
# EDGE CASE TEST FUNCTIONS
# =============================================================================

# Test very long message
test_very_long_message() {
    local temp_dir="$1"
    
    log_debug "Testing very long message"
    
    # Generate a very long message (1000+ characters)
    local long_message=""
    for i in {1..50}; do
        long_message+="This is a very long message segment number ${i}. "
    done
    
    if run_message_test "Very Long Message" "${long_message}" "${long_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test message with null bytes
test_null_bytes() {
    local temp_dir="$1"
    
    log_debug "Testing message with null bytes"
    
    # Create message with null bytes (this is tricky in bash)
    local test_message="Before null"$'\0'"After null"
    
    if run_message_test "Null Bytes Message" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test unicode characters
test_unicode_message() {
    local temp_dir="$1"
    
    log_debug "Testing unicode message"
    
    local unicode_message="Hello 世界 🌍 café naïve résumé"
    
    if run_message_test "Unicode Message" "${unicode_message}" "${unicode_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test binary data
test_binary_data() {
    local temp_dir="$1"
    
    log_debug "Testing binary data transmission"
    
    # Create a file with binary data
    local binary_file="${temp_dir}/binary_test.bin"
    echo -ne '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F' > "${binary_file}"
    
    # Read binary data as string (this may not work perfectly)
    local binary_message
    binary_message=$(cat "${binary_file}")
    
    if run_message_test "Binary Data" "${binary_message}" "${binary_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test maximum message size
test_max_message_size() {
    local temp_dir="$1"
    
    log_debug "Testing maximum message size"
    
    # Create a message near the system limit
    local max_message=""
    for i in {1..200}; do
        max_message+="0123456789"  # 10 chars per iteration = 2000 chars total
    done
    
    if run_message_test "Maximum Size Message" "${max_message}" "${max_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test rapid message succession
test_rapid_succession() {
    local temp_dir="$1"
    
    log_debug "Testing rapid message succession"
    
    # Start server
    local server_pid
    server_pid=$(start_server "${SERVER_BINARY}")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    sleep "${SERVER_START_DELAY}"
    
    # Send messages in rapid succession
    local success_count=0
    local total_messages=10
    
    for i in $(seq 1 ${total_messages}); do
        local message="Rapid message ${i}"
        
        # Start client in background
        if timeout 5 "${CLIENT_BINARY}" "${server_pid}" "${message}" >/dev/null 2>&1; then
            ((success_count++))
        fi
        
        # No delay between messages (this is the edge case)
    done
    
    # Wait for all messages to be processed
    sleep 2
    
    # Stop server
    stop_server "${server_pid}"
    
    # Test passes if most messages were handled (some may fail due to rapid succession)
    local success_rate=$((success_count * 100 / total_messages))
    log_debug "Rapid succession test: ${success_count}/${total_messages} messages (${success_rate}%)"
    
    # Accept 70% success rate for rapid succession
    [[ ${success_rate} -ge 70 ]]
}

# Test concurrent clients
test_concurrent_clients() {
    local temp_dir="$1"
    
    log_debug "Testing concurrent clients"
    
    # Start server
    local server_pid
    server_pid=$(start_server "${SERVER_BINARY}")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    sleep "${SERVER_START_DELAY}"
    
    # Start multiple clients simultaneously
    local client_pids=()
    local num_clients=5
    
    for i in $(seq 1 ${num_clients}); do
        local message="Concurrent message from client ${i}"
        # Start client in background
        (
            timeout 10 "${CLIENT_BINARY}" "${server_pid}" "${message}" >"${temp_dir}/client_${i}.out" 2>&1
        ) &
        client_pids+=("$!")
    done

    # Wait for all clients to finish
    local success_count=0
    for pid in "${client_pids[@]}"; do
        if wait "$pid"; then
            ((success_count++))
        fi
    done

    # Stop server
    stop_server "${server_pid}"

    log_debug "Concurrent clients test: ${success_count}/${num_clients} clients succeeded"
    # Accept 80% success rate for concurrency
    [[ ${success_count} -ge $((num_clients * 8 / 10)) ]]
}

# Run all edge tests
run_edge_tests() {
    log_section "Edge Case Tests"
    local temp_dir="${RESULTS_DIR}/edge_temp"
    mkdir -p "${temp_dir}"
    EDGE_TOTAL=0
    EDGE_PASSED=0
    EDGE_FAILED=0

    local tests=(
        test_very_long_message
        test_null_bytes
        test_unicode_message
        test_binary_data
        test_max_message_size
        test_rapid_succession
        test_concurrent_clients
    )

    for test_func in "${tests[@]}"; do
        ((EDGE_TOTAL++))
        if $test_func "$temp_dir"; then
            ((EDGE_PASSED++))
        else
            ((EDGE_FAILED++))
        fi
    done
}