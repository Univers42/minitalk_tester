#!/bin/bash

# =============================================================================
# TEST RUNNER ENGINE
# =============================================================================
# Core test execution engine with utilities for running minitalk tests
# =============================================================================

# Test execution variables
TEST_TIMEOUT=10
SERVER_START_DELAY=1
CLIENT_TIMEOUT=5
TEMP_DIR="${RESULTS_DIR}/temp"

# Test counters (will be set by individual test files)
declare -g TOTAL_TESTS=0
declare -g PASSED_TESTS=0
declare -g FAILED_TESTS=0

# =============================================================================
# TEST INFRASTRUCTURE
# =============================================================================

# Initialize test environment
init_test_environment() {
    log_debug "Initializing test environment"
    
    # Create temporary directory
    mkdir -p "${TEMP_DIR}"
    
    # Clean any existing server processes
    cleanup_processes
    
    # Load test configuration
    load_test_config
    
    log_debug "Test environment ready"
}

# Load test configuration
load_test_config() {
    local config_file="${SCRIPT_DIR}/config/settings.conf"
    
    if [[ -f "${config_file}" ]]; then
        log_debug "Loading configuration from ${config_file}"
        source "${config_file}"
    else
        log_warning "Configuration file not found: ${config_file}"
        log_info "Using default settings"
    fi
}

# Clean up any leftover processes
cleanup_processes() {
    log_debug "Cleaning up processes"
    
    # Kill any running server processes (minitalk servers)
    pkill -f "${SERVER_BINARY##*/}" 2>/dev/null || true
    
    # Wait a moment for cleanup
    sleep 1
}

# =============================================================================
# CORE TEST EXECUTION FUNCTIONS
# =============================================================================

# Execute a single test
run_test() {
    local test_name="$1"
    local test_function="$2"
    local expected_result="${3:-PASS}"
    
    log_debug "Running test: ${test_name}"
    
    # Initialize test result
    local test_result="FAIL"
    local test_details=""
    local start_time=$(date +%s)
    
    # Create test-specific temp directory
    local test_temp_dir="${TEMP_DIR}/${test_name// /_}"
    mkdir -p "${test_temp_dir}"
    
    # Execute the test function
    if ${test_function} "${test_temp_dir}"; then
        test_result="PASS"
        test_details="Test completed successfully"
    else
        test_result="FAIL"
        test_details="Test function returned error"
    fi
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    test_details="${test_details} (${duration}s)"
    
    # Update counters
    ((TOTAL_TESTS++))
    if [[ "${test_result}" == "PASS" ]]; then
        ((PASSED_TESTS++))
    else
        ((FAILED_TESTS++))
    fi
    
    # Log the result
    log_test_result "${test_name}" "${test_result}" "${test_details}"
    
    # Cleanup test-specific resources
    cleanup_test_resources "${test_temp_dir}"
    
    return $([[ "${test_result}" == "PASS" ]] && echo 0 || echo 1)
}

# Run a message transmission test
run_message_test() {
    local test_name="$1"
    local message="$2"
    local expected_output="$3"
    local temp_dir="$4"
    
    log_debug "Message test: '${message}'"
    
    # Start server
    local server_pid
    server_pid=$(start_server "${SERVER_BINARY}")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to start server for test: ${test_name}"
        return 1
    fi
    
    # Wait for server to be ready
    sleep "${SERVER_START_DELAY}"
    
    # Capture server output before sending message
    local server_output_before=""
    if [[ -f "${RESULTS_DIR}/server.out" ]]; then
        server_output_before=$(cat "${RESULTS_DIR}/server.out")
    fi
    
    # Run client
    local client_output
    client_output=$(run_client "${CLIENT_BINARY}" "${server_pid}" "${message}" "${CLIENT_TIMEOUT}")
    local client_exit_code=$?
    
    # Wait a moment for server to process
    sleep 1
    
    # Capture server output after sending message
    local server_output_after=""
    if [[ -f "${RESULTS_DIR}/server.out" ]]; then
        server_output_after=$(cat "${RESULTS_DIR}/server.out")
    fi
    
    # Extract the new server output (message received)
    local received_message=""
    if [[ -n "${server_output_after}" ]]; then
        received_message=$(echo "${server_output_after}" | sed "s|${server_output_before}||" | tr -d '\n' | sed 's/^[[:space:]]*//')
    fi
    
    # Stop server
    stop_server "${server_pid}"
    
    # Evaluate test result
    local test_passed=false
    
    if [[ ${client_exit_code} -eq 0 ]]; then
        if [[ -z "${expected_output}" ]]; then
            # No specific output expected, just check if message was received
            if [[ "${received_message}" == "${message}" ]]; then
                test_passed=true
            fi
        else
            # Check for specific expected output
            if [[ "${received_message}" == "${expected_output}" ]]; then
                test_passed=true
            fi
        fi
    fi
    
    # Log detailed results in verbose mode
    if [[ "${VERBOSE}" == true ]]; then
        log_debug "Client exit code: ${client_exit_code}"
        log_debug "Sent message: '${message}'"
        log_debug "Received message: '${received_message}'"
        log_debug "Expected output: '${expected_output:-${message}}'"
    fi
    
    # Save test details to file
    {
        echo "Test: ${test_name}"
        echo "Sent: ${message}"
        echo "Received: ${received_message}"
        echo "Expected: ${expected_output:-${message}}"
        echo "Client Exit Code: ${client_exit_code}"
        echo "Result: $([[ ${test_passed} == true ]] && echo "PASS" || echo "FAIL")"
        echo "---"
    } >> "${temp_dir}/test_details.log"
    
    [[ ${test_passed} == true ]]
}

# Run a stress test with multiple messages
run_stress_test() {
    local test_name="$1"
    local message_count="$2"
    local message_template="$3"
    local temp_dir="$4"
    
    log_debug "Stress test: ${message_count} messages"
    
    # Start server
    local server_pid
    server_pid=$(start_server "${SERVER_BINARY}")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to start server for stress test: ${test_name}"
        return 1
    fi
    
    sleep "${SERVER_START_DELAY}"
    
    # Send multiple messages
    local success_count=0
    local start_time=$(date +%s)
    
    for ((i=1; i<=message_count; i++)); do
        local message="${message_template} ${i}"
        
        if run_client "${CLIENT_BINARY}" "${server_pid}" "${message}" "${CLIENT_TIMEOUT}" >/dev/null 2>&1; then
            ((success_count++))
        fi
        
        # Show progress for long tests
        if [[ $((i % 10)) -eq 0 ]] && [[ ${VERBOSE} == true ]]; then
            log_progress "${i}" "${message_count}" "Sending messages"
        fi
        
        # Small delay between messages
        sleep 0.1
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Stop server
    stop_server "${server_pid}"
    
    # Evaluate results
    local success_rate=$((success_count * 100 / message_count))
    
    log_debug "Stress test completed: ${success_count}/${message_count} messages sent successfully"
    log_debug "Success rate: ${success_rate}%, Duration: ${duration}s"
    
    # Save stress test results
    {
        echo "Stress Test: ${test_name}"
        echo "Messages Sent: ${message_count}"
        echo "Successful: ${success_count}"
        echo "Success Rate: ${success_rate}%"
        echo "Duration: ${duration}s"
        echo "Messages per second: $((message_count / duration))"
    } >> "${temp_dir}/stress_test_results.log"
    
    # Test passes if success rate is above threshold (configurable)
    local min_success_rate=${STRESS_TEST_MIN_SUCCESS_RATE:-80}
    [[ ${success_rate} -ge ${min_success_rate} ]]
}

# =============================================================================
# TEST UTILITIES
# =============================================================================

# Generate test message from template
generate_test_message() {
    local template="$1"
    local index="${2:-1}"
    
    # Replace placeholders in template
    echo "${template}" | sed -e "s/{INDEX}/${index}/g" \
                            -e "s/{RANDOM}/$(generate_random_string 5)/g" \
                            -e "s/{TIME}/$(date +%H:%M:%S)/g"
}

# Validate message transmission
validate_message() {
    local sent="$1"
    local received="$2"
    local test_type="${3:-exact}"
    
    case "${test_type}" in
        "exact")
            [[ "${sent}" == "${received}" ]]
            ;;
        "contains")
            [[ "${received}" == *"${sent}"* ]]
            ;;
        "length")
            [[ ${#sent} -eq ${#received} ]]
            ;;
        *)
            log_error "Unknown validation type: ${test_type}"
            return 1
            ;;
    esac
}

# Cleanup test resources
cleanup_test_resources() {
    local test_temp_dir="$1"
    
    # Clean up temporary files (but keep logs for debugging)
    if [[ -d "${test_temp_dir}" ]]; then
        find "${test_temp_dir}" -name "*.tmp" -delete 2>/dev/null || true
    fi
    
    # Make sure no server processes are left running
    cleanup_processes
}

# =============================================================================
# RESULT MANAGEMENT
# =============================================================================

# Save test suite results
save_test_results() {
    local suite_name="$1"
    local results_file="${RESULTS_DIR}/${suite_name}_results.json"
    
    # Create JSON results file
    {
        echo "{"
        echo "  \"suite\": \"${suite_name}\","
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"total_tests\": ${TOTAL_TESTS},"
        echo "  \"passed_tests\": ${PASSED_TESTS},"
        echo "  \"failed_tests\": ${FAILED_TESTS},"
        echo "  \"success_rate\": $(( PASSED_TESTS * 100 / TOTAL_TESTS )),"
        echo "  \"configuration\": {"
        echo "    \"server_binary\": \"${SERVER_BINARY}\","
        echo "    \"client_binary\": \"${CLIENT_BINARY}\","
        echo "    \"test_timeout\": ${TEST_TIMEOUT}"
        echo "  }"
        echo "}"
    } > "${results_file}"
    
    log_debug "Results saved to: ${results_file}"
}

# Reset test counters
reset_test_counters() {
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
}

# Get test statistics
get_test_stats() {
    echo "Total: ${TOTAL_TESTS}, Passed: ${PASSED_TESTS}, Failed: ${FAILED_TESTS}"
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Initialize test runner when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    init_test_environment
fi