#!/usr/bin/env sh

#  (The MIT License)
#
#  Copyright (c) 2019 Mamadou Babaei
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.


set +e

readonly BASENAME="basename"
readonly CUT="/usr/bin/cut"
readonly ECHO="echo -e"
readonly GREP="/usr/bin/grep"
readonly LOGGER="/usr/bin/logger"
readonly PS="/bin/ps"
readonly REV="/usr/bin/rev"
readonly TR="/usr/bin/tr"

readonly FMT_OFF='\e[0m'
readonly FMT_INFO='\e[1;32m'
readonly FMT_WARN='\e[1;33m'
readonly FMT_ERR='\e[1;91m'
readonly FMT_FATAL='\e[1;31m'

readonly LOG_INFO="INFO"
readonly LOG_WARN="WARNING"
readonly LOG_ERR="ERROR"
readonly LOG_FATAL="FATAL"

readonly SCRIPT="$0"
readonly SCRIPT_NAME="$(${BASENAME} -- "${SCRIPT}")"
readonly SYSLOG_TAG="$(${BASENAME} -- "${SCRIPT}" \
    | ${TR} '[:lower:]' '[:upper:]' \
    | ${REV} \
    | ${CUT} -d "." -f2- \
    | ${REV})"

usage()
{
    ${ECHO}
    ${ECHO} "${FMT_INFO}Correct usage:${FMT_OFF}"
    ${ECHO}
    ${ECHO} "    ${FMT_INFO}${SCRIPT_NAME} -e {executable full path} -s {service name to (re)start} [-s {another service name to (re)start}] [... even more -s and service names to (re)start]${FMT_OFF}"
    ${ECHO}

    exit 1
}

log()
{
    log_type=$1; shift
    fmt=$1; shift

    if [ -n "$1" -a -n "$@" ] ;
    then
        ${ECHO} "${fmt}[${log_type}] $@${FMT_OFF}"
        ${LOGGER} -t "${SYSLOG_TAG}" "${log_type} $@"
    fi 
}

info()
{
    log "${LOG_INFO}" "${FMT_INFO}" "$@"
}

warn()
{
    log "${LOG_WARN}" "${FMT_WARN}" "$@"
}

err()
{
    log "${LOG_ERR}" "${FMT_ERR}" "$@"
}

fatal()
{
    log "${LOG_FATAL}" "${FMT_FATAL}" "$@"
    exit 1
}

restart_service()
{
    service_name="$1"

    info "Stopping the service '${service_name}'..."
    service ${service_name} stop > /dev/null 2>&1

    if [ "$?" -eq 0 ] ;
    then
        info "The '${service_name}' service has been stopped successfully!"
    else
        err "Failed to stop the '${service_name}' service!"
    fi

    info "Starting the service '${service_name}'..."
    service ${service_name} start > /dev/null 2>&1

    if [ "$?" -eq 0 ] ;
    then
        info "The '${service_name}' service has been started successfully!"
    else
        err "Failed to start the '${service_name}' service!"
    fi
}

if [ "$#" -eq 0 ] ;
then
    usage
fi

SERVICE_COUNT=0

while getopts ":e: :s:" ARG ;
do
    case ${ARG} in
        e)
            if [ -z "${OPTARG}" ] ;
            then
                err "Missing executable ${OPTARG}!"
                usage
            fi

            if [ ! -f "${OPTARG}" ] ;
            then
                fatal "The executable '${OPTARG}' does not exist!"
            fi

            readonly DAEMON="${OPTARG}"
            ;;
        s)
            if [ ! -f "/usr/etc/rc.d/${OPTARG}" \
                -a ! -f "/usr/local/etc/rc.d/${OPTARG}" ] ;
            then
                fatal "No such a service exists: '${OPTARG}'!"
            fi

            SERVICE_COUNT=$((SERVICE_COUNT+1))
            ;;
        \?)
            err "Invalid option: -${OPTARG}!"
            usage
        ;;
    esac
done

if [ "${SERVICE_COUNT}" -eq 0 ] ;
then
    err "At least one service name is required!"
    usage
fi

readonly DAEMON_PROCESS_COUNT=$(${PS} aux \
    | ${GREP} -v "${GREP}" \
    | ${GREP} -v "${SCRIPT}" \
    | ${GREP} -c "${DAEMON}")

if [ "${DAEMON_PROCESS_COUNT}" -lt 1 ] ;
then
    warn "'${DAEMON}' is not running!"

    OPTIND=1
    while getopts ":e: :s:" ARG ;
    do
        case ${ARG} in
            s)
                restart_service "${OPTARG}"
                ;;
            \?)
            ;;
        esac
    done
else
    info "'${DAEMON}' is running!"
    info "No action is required!"
fi
