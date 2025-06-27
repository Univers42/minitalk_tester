#!/bin/bash

parse_arguments()
{
	RUN_BASIC=false
	RUN_EDGE=false
	RUN_PERFORMANCE=false
	RUN_ALL=false
	VERBOSE=false
	QUIET=false
	CLEAN_ONLY=false
	MESSAGE="just a message"
	SERVER_BINARY=""
	CLIENT_BINARY=""
	SHOW_USAGE=false
	RUN_TESTER_MINITALK=false
	PERFORMANCE_MODE=false

	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				SHOW_USAGE=true
				shift
				;;
			-v|--verbose)
				VERBOSE=true
				SHOW_USAGE=true   # <-- Add this line so -v triggers usage
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
				PERFORMANCE_MODE=true
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
			-m|--message)
				MESSAGE="$2"
				shift 2
				;;
			--server-path)
				SERVER_BINARY="$2"
				shift 2
				;;
			--client-path)
				CLIENT_BINARY="$2"
				shift 2
				;;
			-tm|--tester-minitalk)
				RUN_TESTER_MINITALK=true
				shift
				;;
			-tmp|--tester-minitalk-performance)
				RUN_TESTER_MINITALK=true
				PERFORMANCE_MODE=true
				shift
				;;
			*)
				log_error "unknown option: $1"
				SHOW_USAGE=true
				shift
				;;
		esac
	done
}