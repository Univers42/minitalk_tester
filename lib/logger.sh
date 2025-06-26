#/bin/bash

LOG_LEVEL_ERROR=0
LOG_LEVEL_WARN=1
LOG_LEVEL_INFO=2
LOG_LEVEL_DEBUG=3

#default log level
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

#set the log file name with main script

# Define color variables if not already defined
RESET="\033[0m"
BOLD="\033[1m"
BOLD_RED="\033[1;31m"
BOLD_GREEN="\033[1;32m"
BOLD_YELLOW="\033[1;33m"
BOLD_BLUE="\033[1;34m"
BOLD_CYAN="\033[1;36m"
GRAY="\033[0;37m"
RED="\033[0;31m"

# Define symbols if not already defined
FAILURE_SYMBOL="✗"
WARNING_SYMBOL="!"
INFO_SYMBOL="ℹ"
SUCCESS_SYMBOL="✔"
PASS="✔"
FAIL="✗"

# Set default log file if not set
: "${LOG_FILE:=minitalk.log}"

# ============================================================== #
# LOGGING INITIALIZATION                                         #
# ============================================================== #


# ============================================================= #
# FORMAT LOG MESSAGES											#
# ============================================================= #

_log()
{
	local level=$1
	local level_name=$2
	local color=$3
	local symbol=$4
	local message="$5"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	if [[ ${level} -le ${CURRENT_LOG_LEVEL} ]]; then
		echo -e "${symbol} ${color}${message}${RESET}"
	fi
	echo "[${timestamp}] [${level_name}] ${message}" >> "${LOG_FILE}"
}

log_error()
{
	_log ${LOG_LEVEL_ERROR} "ERROR" "${BOLD_RED}" "${FAILURE_SYMBOL}" "$1"
}

log_warning()
{
	_log ${LOG_LEVEL_WARN} "WARNING" "${BOLD_YELLOW}" "${WARNING_SYMBOL}" "$1"
}

log_info()
{
	_log ${LOG_LEVEL_INFO} "INFO" "${BOLD_BLUE}" "${INFO_SYMBOL}" "$1"
}

log_debug()
{
	_log ${LOG_LEVEL_DEBUG} "DEBUG" "${GRAY}" "${INFO_SYMBOL}" "$1" 
}

log_success()
{
	_log ${LOG_LEVEL_INFO} "SUCCESS" "${BOLD_GREEN}" "${SUCCESS_SYMBOL}" "$1"
}

# ===================================================================== #
# LOGGING FUNCTIONS														#
# ===================================================================== #

log_test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "${result}" == "PASS" ]]; then
        if [[ ${CURRENT_LOG_LEVEL} -ge ${LOG_LEVEL_INFO} ]]; then
            echo -e "${PASS} ${BOLD}${test_name}${RESET}"
            if [[ -n "${details}" && "${VERBOSE}" == true ]]; then
                echo -e "      ${GRAY}${details}${RESET}"
            fi
        fi
        echo "[${timestamp}] [TEST] PASS: ${test_name} - ${details}" >> "${LOG_FILE}"
    else
        if [[ ${CURRENT_LOG_LEVEL} -ge ${LOG_LEVEL_ERROR} ]]; then
            echo -e "${FAIL} ${BOLD}${test_name}${RESET}"
            if [[ -n "${details}" ]]; then
                echo -e "      ${RED}${details}${RESET}"
            fi
        fi
        echo "[${timestamp}] [TEST] FAIL: ${test_name} - ${details}" >> "${LOG_FILE}"
    fi
}


log_header() {
    local title="$1"
    local color="${2:-${BOLD_CYAN}}"
    
    if [[ ${CURRENT_LOG_LEVEL} -ge ${LOG_LEVEL_INFO} ]]; then
        print_header "${title}" "${color}"
    fi
    
    echo >> "${LOG_FILE}"
    echo "=============================================" >> "${LOG_FILE}"
    echo " ${title}" >> "${LOG_FILE}"
    echo "=============================================" >> "${LOG_FILE}"
}

log_section() {
    local title="$1"
    local color="${2:-${BOLD_BLUE}}"
    
    if [[ ${CURRENT_LOG_LEVEL} -ge ${LOG_LEVEL_INFO} ]]; then
        print_section "${title}" "${color}"
    fi
    
    echo >> "${LOG_FILE}"
    echo "--- ${title} ---" >> "${LOG_FILE}"
}

log_command() {
    local command="$1"
    local show_output="${2:-false}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_debug "Executing: ${command}"
    echo "[${timestamp}] [CMD] ${command}" >> "${LOG_FILE}"
    
    if [[ "${show_output}" == true || "${VERBOSE}" == true ]]; then
        # Execute and show output
        eval "${command}" 2>&1 | tee -a "${LOG_FILE}"
        local exit_code=${PIPESTATUS[0]}
    else
        # Execute silently, log output to file
        eval "${command}" >> "${LOG_FILE}" 2>&1
        local exit_code=$?
    fi
    
    if [[ ${exit_code} -eq 0 ]]; then
        log_debug "Command succeeded (exit code: ${exit_code})"
    else
        log_error "Command failed (exit code: ${exit_code})"
    fi
    
    return ${exit_code}
}

log_progress()
{
	local current=$1
	local total=$2
	local task="${3:-Processing}"

	if [[ ${CURRENT_LOG_LEVEL} -ge ${LOG_LEVEL_INFO} ]];then
		progress_bar "${current}" "${total}"
	fi
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PROGRESS] ${task}: ${current}/${total}" >> "${LOG_FILE}"
}

# ================================================================= #
# UTILITY FUNCTIONS													#
# ================================================================= #
set_log_level()
{
	case "$1" in
		"error"|"ERROR"|0)
			CURRENT_LOG_LEVEL=${LOG_LEVEL_ERROR}
			;;
		"warn"|"WARN"|1)
			CURRENT_LOG_LEVEL=${LOG_LEVEL_WARNING}
			;;
		"info"|"INFO"|2)
			CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}
			;;
		"debug"|"DEBUG"|3)
			CURRENT_LOG_LEVEL=${LOG_LEVEL_DEBUG}
			;;
		*)
			log_error "invalid log level: $1"
			return 1
			;;
	esac
	log_info "Log level set to: $1"
}

get_log_level()
{
	case ${CURRENT_LOG_LEVEL} in
		${LOG_LEVEL_ERROR}) echo "ERROR" ;;
		${LOG_LEVEL_WARN}) echo "WARN" ;;
		${LOG_LEVEL_INFO}) echo "INFO" ;;
		${LOG_LEVEL_DEBUG}) echo "DEBUG" ;;
		*) echo "UNKNOWN" ;;
	esac
}

rotate_log()
{
	local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
	if [[ -f "${LOG_FILE}" ]]; then
		local backup_file="${LOG_FILE}.${TIMESTAMP}.bak"
		mv ${LOG_FILE} "$backup_file"
		log_info "Log related to: ${backup_file}"
		init_logging "${LOG_FILE}"
	fi
}

check_log_size()
{
	local max_size_mb=${1:-10}

	if [[ -f "${LOG_FILE}" ]]; then
		local size_mb= $(du -m "${LOG_FILE}" | cut -f1)
		if [[ ${size_mb} -gt ${max_size_mb} ]]; then
			log_warning "Log file size (${size_mb}MB) exceeds limit ($(max_size_mb)MB)"
			return 1
		fi
	fi
	return 0
}


export LOG_FILE CURRENT_LOG_FILE
export LOG_LEVEL_ERROR LOG_LEVEL_WARN LOG_LEVEL_INFO LOG_LEVEL_DEBUG