#!/bin/bash

# =============================================================================
# BASIC TESTS SUITE
# =============================================================================
# Fundamental functionality tests for minitalk project
# =============================================================================

# Test suite counters
BASIC_TOTAL=0
BASIC_PASSED=0
BASIC_FAILED=0

# =============================================================================
# BASIC TEST FUNCTIONS
# =============================================================================

# Test simple message transmission
test_simple_message() {
    local temp_dir="$1"
    
    log_debug "Testing simple message transmission"
    
    local test_message="Hello World"
    
    # Use the test runner's message test function
    if run_message_test "Simple Message" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test empty message
test_empty_message() {
    local temp_dir="$1"
    
    log_debug "Testing empty message"
    
    local test_message=""
    
    # Empty message should not crash the system
    if run_message_test "Empty Message" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test single character message
test_single_character() {
    local temp_dir="$1"
    
    log_debug "Testing single character message"
    
    local test_message="A"
    
    if run_message_test "Single Character" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test numeric message
test_numeric_message() {
    local temp_dir="$1"
    
    log_debug "Testing numeric message"
    
    local test_message="1234567890"
    
    if run_message_test "Numeric Message" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test alphanumeric message
test_alphanumeric_message() {
    local temp_dir="$1"
    
    log_debug "Testing alphanumeric message"
    
    local test_message="Test123Message456"
    
    if run_message_test "Alphanumeric Message" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test message with spaces
test_message_with_spaces() {
    local temp_dir="$1"
    
    log_debug "Testing message with spaces"
    
    local test_message="This is a test message with spaces"
    
    if run_message_test "Message with Spaces" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test message with special characters
test_special_characters() {
    local temp_dir="$1"
    
    log_debug "Testing message with special characters"
    
    local test_message="!@#$%^&*()_+-=[]{}|;:,.<>?"
    
    if run_message_test "Special Characters" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test message with newlines
test_message_with_newlines() {
    local temp_dir="$1"
    
    log_debug "Testing message with newlines"
    
    local test_message="Line 1\nLine 2\nLine 3"
    
    if run_message_test "Message with Newlines" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test short message
test_short_message() {
    local temp_dir="$1"
    
    log_debug "Testing short message"
    
    local test_message="Hi"
    
    if run_message_test "Short Message" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test medium length message
test_medium_message() {
    local temp_dir="$1"
    
    log_debug "Testing medium length message"
    
    local test_message="This is a medium length message that should test the system's ability to handle moderate amounts of text without any issues."
    
    if run_message_test "Medium Length Message" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test message with quotes
test_message_with_quotes() {
    local temp_dir="$1"
    
    log_debug "Testing message with quotes"
    
    local test_message="This is a \"quoted\" message with 'single' and \"double\" quotes"
    
    if run_message_test "Message with Quotes" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test message with tabs
test_message_with_tabs() {
    local temp_dir="$1"
    
    log_debug "Testing message with tabs"
    
    local test_message="Column1	Column2	Column3"
    
    if run_message_test "Message with Tabs" "${test_message}" "${test_message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Test server restart functionality
test_server_restart() {
    local temp_dir="$1"
    
    log_debug "Testing server restart functionality"
    
    # Start server
    local server_pid
    server_pid=$(start_server "${SERVER_BINARY}")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Send first message
    local message1="First message"
    if ! run_client "${CLIENT_BINARY}" "${server_pid}" "${message1}" "${CLIENT_TIMEOUT}" >/dev/null 2>&1; then
        stop_server "${server_pid}"
        return 1
    fi
    
    # Stop server
    stop_server "${server_pid}"
    
    # Wait a moment
    sleep 2
    
    # Restart server
    server_pid=$(start_server "${SERVER_BINARY}")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Send second message
    local message2="Second message after restart"
    if ! run_client "${CLIENT_BINARY}" "${server_pid}" "${message2}" "${CLIENT_TIMEOUT}" >/dev/null 2>&1; then
        stop_server "${server_pid}"
        return 1
    fi
    
    # Stop server
    stop_server "${server_pid}"
    
    return 0
}

# Test multiple quick messages
test_multiple_quick_messages() {
    local temp_dir="$1"
    
    log_debug "Testing multiple quick messages"
    
    # Start server
    local server_pid
    server_pid=$(start_server "${SERVER_BINARY}")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    sleep "${SERVER_START_DELAY}"
    
    # Send multiple messages quickly
    local success=true
    for i in {1..5}; do
        local message="Quick message ${i}"
        if ! run_client "${CLIENT_BINARY}" "${server_pid}" "${message}" "${CLIENT_TIMEOUT}" >/dev/null 2>&1; then
            success=false
            break
        fi
        sleep 0.1  # Small delay between messages
    done
    
    # Stop server
    stop_server "${server_pid}"
    
    [[ ${success} == true ]]
}

# Test invalid PID handling
test_invalid_pid() {
    local temp_dir="$1"
    
    log_debug "Testing invalid PID handling"
    
    # Try to send message to non-existent PID
    local fake_pid=99999
    local test_message="This should fail"
    
    # Client should fail gracefully
    if run_client "${CLIENT_BINARY}" "${fake_pid}" "${test_message}" "${CLIENT_TIMEOUT}" >/dev/null 2>&1; then
        # If client succeeds with fake PID, that's unexpected
        return 1
    else
        # Client should fail with invalid PID
        return 0
    fi
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

# Run all basic tests
run_basic_tests() {
    log_header "BASIC FUNCTIONALITY TESTS"
    
    # Reset counters
    reset_test_counters
    
    # Define test array
    local tests=(
        "Simple Message:test_simple_message"
        "Empty Message:test_empty_message"
        "Single Character:test_single_character"
        "Numeric Message:test_numeric_message"
        "Alphanumeric Message:test_alphanumeric_message"
        "Message with Spaces:test_message_with_spaces"
        "Special Characters:test_special_characters"
        "Message with Newlines:test_message_with_newlines"
        "Short Message:test_short_message"
        "Medium Length Message:test_medium_message"
        "Message with Quotes:test_message_with_quotes"
        "Message with Tabs:test_message_with_tabs"
        "Server Restart:test_server_restart"
        "Multiple Quick Messages:test_multiple_quick_messages"
        "Invalid PID Handling:test_invalid_pid"
    )
    
    log_info "Running ${#tests[@]} basic tests..."
    
    # Run each test
    for test_spec in "${tests[@]}"; do
        local test_name="${test_spec%:*}"
        local test_function="${test_spec#*:}"
        
        run_test "${test_name}" "${test_function}"
    done
    
    # Set results for main script
    BASIC_TOTAL=${TOTAL_TESTS}
    BASIC_PASSED=${PASSED_TESTS}
    BASIC_FAILED=${FAILED_TESTS}
    
    # Save results
    save_test_results "basic_tests"
    
    # Print summary
    log_section "Basic Tests Summary"
    echo -e "${BOLD}Tests Run:    ${BLUE}${BASIC_TOTAL}${RESET}"
    echo -e "${BOLD}Passed:       ${GREEN}${BASIC_PASSED}${RESET}"
    echo -e "${BOLD}Failed:       ${RED}${BASIC_FAILED}${RESET}"
    
    if [[ ${BASIC_FAILED} -eq 0 ]]; then
        log_success "All basic tests passed! ✨"
    else
        log_warning "${BASIC_FAILED} basic test(s) failed"
    fi
    
    echo
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Load test messages from file
load_test_messages() {
    local messages_file="${SCRIPT_DIR}/config/messages.txt"
    
    if [[ -f "${messages_file}" ]]; then
        log_debug "Loading test messages from ${messages_file}"
        mapfile -t TEST_MESSAGES < "${messages_file}"
    else
        log_warning "Messages file not found: ${messages_file}"
        # Use default messages
        TEST_MESSAGES=(
            "Hello World"
            "Test message 123"
            "Special chars: !@#$%^&*()"
            "Multi-line\nmessage\ntest"
            ""
            "A"
            "Very long message that tests the system's ability to handle extended text without issues or corruption"
        )
    fi
}

# Run tests with messages from file
run_message_file_tests() {
    load_test_messages
    
    log_section "Testing with predefined messages"
    
    local message_index=0
    for message in "${TEST_MESSAGES[@]}"; do
        ((message_index++))
        local test_name="Message ${message_index}"
        
        run_test "${test_name}" "test_file_message" "${message}"
    done
}

# Test function for file messages
test_file_message() {
    local temp_dir="$1"
    local message="$2"
    
    if run_message_test "File Message" "${message}" "${message}" "${temp_dir}"; then
        return 0
    else
        return 1
    fi
}

# Initialize basic tests
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    log_debug "Basic tests module loaded"
fi