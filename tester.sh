# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    tester.sh                                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: dlesieur <dlesieur@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/06/26 15:40:31 by dlesieur          #+#    #+#              #
#    Updated: 2025/06/26 19:27:43 by dlesieur         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#!/bin/bash

# why not just pwd ?
# while pwd give use the current path directory where we run the script
# the dirname help to get the path directory  containing the script no
# matter where we run it at a different location or not 
# if we run the script from another directory it would be
# cd /tmp && ./path/to/tester.sh
# with script_dir it is :
# /path/to/
# ! best practice for portable bash script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and libraries
# source work like includes we includes the files
# to get their logic
source "${SCRIPT_DIR}/config/colors.sh"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/test_runner.sh"

# Global variables
MINITALK_PATH="${SCRIPT_DIR}/../"  # Adjust path to your minitalk project
SERVER_BINARY="${MINITALK_PATH}/server"
CLIENT_BINARY="${MINITALK_PATH}/client"
RESULTS_DIR="${SCRIPT_DIR}/results"
LOG_FILE="${RESULTS_DIR}/test_$(date +%Y%m%d_%H%M%S).log"

# ================================================================= #
# MAIN FUNCTIONS                                                    #
# ================================================================= #

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
	echo -e "   --server-path		Custom server binary path"
	echo -e "   --client-path		Custom client binary path"
	echo
	echo -e "${GREEN}Examples:${RESET}"
	echo -e "  $0                  # Run all tests"
	echo -e "  $0 -b -v            # Run basic tests with verbose output"
	echo -e "  $0 --clean          # Clean results and exit"
}

parse_arguments()
{
	RUN_BASIC=false
	RUN_EDGE=false
	RUN_PERFORMANCE=false
	RUN_ALL=false
	VERBOSE=false
	QUIET=false
	CLEAN_ONLY=false

	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				show_usage
				exit0
				;;
			-v|--verbose)
				VERBOSE=true
				shift
				;;
			-q|--quiet)
				QUIET=true
				shift
				;;
			-b|--basic)
				RUN_BASIC=true
				shift
				;;
			-e|--edge)
				RUN_EDGE=true
				shift
				;;
			-p|--performance)
				RUN_PERFORMANCE=true
				shift
				;;
			-a|--all)
				RUN_ALL=true
				shift
				;;
			-c|--clean)
				CLEAN_ONLY=true
				shift
				;;
			--server-path)
				SERVER_BINARY="$2"
				shift 2
				;;
			--client-path)
				CLIENT_BINARY="$2"
				shift 2
				;;
			*)
				log_error "unknown option: $1"
				show_usage
				exit 1
				;;
		esac
	done
}

setup_environment()
{
	mkdir -p "${RESULT_DIR}"
	init_logging "${LOG_FILE}"
	log_info "Minitalk Tester Starting..."
	log_info "Results directory: ${RESULTS_DIR}"
	log_info "Log file: ${LOG_FILE}"
}

check_prerequesites()
{
	log_info "Checking prerequisites..."
	
	# Check if the binary server is available
	if [[ ! -f "${SERVER_BINARY}" ]]; then
		log_error "Server binary not found: ${SERVER_BINARY}"
		log_info "Please compile your minitalk project first"
		exit 1
	fi
	
	#check if the binary client is available
	if [[ ! -f "${CLIENT_BINARY}" ]]; then
		log_error "Client binary not found: ${CLIENT_BINARY}"
		log_info "Please compile your minitalk project first"
		exit 1
	fi

	#Check if binaries are executables
	if [[ ! -x ${SERVER_BINARY} && ! -x ${CLIENT_BINARY} ]]; then
		log_error "Check both bin (meaning ${SERVER_BINARY} and ${CLIENT_BINARY}) if they are executables."
		log_info "chmod +x ${SERVER_BINARY} ${CLIENT_BINARY}"
		exit 1
	fi

	log_success "Prerequisites check passed"
}

clean_results()
{
	if [[-d "$RESULTS_DIR" ]]; then
		log_info "Cleaning previous results..."
		rm -rf "${RESULTS_DIR}"/*
		log_success "Result cleaned"
	fi
}

run_test_suites()
{
	local	total_tests=0
	local	passed_tests=0
	local	failed_tests=0

	log_header "Starting Test Execution..."
	if [[ "${RUN_ALL}" == true ]] || [[ "${RUN_BASICS}" == true ]]; then
		log_info "Running basic tests..."
		source "${SCRIPT_DIR}/tests/basic_tests.sh"
		run_basic_tests
		total_tests=$((total_tests + BASIC_TOTAL))
		passed_tests=$((passed_tests + BASIC_PASSED))
		failed_tests=$((failed_tests + BASIC_FAILED))
	fi
	if [[ "${RUN_ALL}" == true ]] || [[ "${RUN_EDGE}" == true ]]; then
		log_info "Running edge cases"
		run_edge_tests
		total_tests=$((total_tests + EDGE_TOTAL))
		passed_tests=$((passed_tests + EDGE_PASSED))
		failed_tests=$((failed_tests + EDGE_FAILED))
		
	fi
	if [[ "${RUN_ALL}" == true ]] || [[ "${RUN_PERFORMANCE}" == true ]]; then
        log_info "Running performance tests..."
        source "${SCRIPT_DIR}/tests/performance_tests.sh"
        run_performance_tests
        total_tests=$((total_tests + PERF_TOTAL))
        passed_tests=$((passed_tests + PERF_PASSED))
        failed_tests=$((failed_tests + PERF_FAILED))
    fi
	generate_summary "${total_tests}" "${passed_tests}" "${failed_tests}"
}

generate_summary()
{
	local total=$1
	local passed=$2
	local failed=$3
	local percentage=0

	if [[ ${total} -gt 0 ]];then
		percentages=$(( (passed * 100) / total ))
	fi
	log_header "Test summary"
	echo -e "${BOLD}Total tests: ${BLUE}${total}${RESET}"
	echo -e "${BOLD}Passed:		${GREEN}${passed}${RESET}"
	echo -e "${BOLD}Failed:		${RED}${failed}${RESET}"
	echo -e "${BOLD}Success Rate:	${CYAN}${percentage}%${RESET}"
	
	{
        echo "Minitalk Test Summary - $(date)"
        echo "=================================="
        echo "Total Tests: ${total}"
        echo "Passed: ${passed}"
        echo "Failed: ${failed}"
        echo "Success Rate: ${percentage}%"
    } > "${RESULTS_DIR}/summary.txt"
	
	if [[ ${failed} -eq 0 ]]; then
        log_success "All tests passed! "
        exit 0
    else
        log_warning "Some tests failed. Check the logs for details."
        exit 1
    fi
}

main()
{
	parse_arguments "$@"
	if [[ ${CLEAN_ONLY} == true ]]; then
		clean_results
		exit 0
	fi
	setup_environment
	check_prerequesites
	run_test_suites
}

export SCRIPT_DIR SERVER_BINARY CLIENT_BINARY RESULTS_DIR LOG_FILE
export VERBOSE QUIET

main "$@"