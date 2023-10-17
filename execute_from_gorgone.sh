#!/usr/bin/env bash
#https://regex101.com/r/yOxL8m/1
token_regex='"token":"\K[A-Z0-9a-z]+'
#https://regex101.com/r/4DELtB/1
no_log_regex='"error":"\Kno_log'
stdout_regex='stdout\\":\\"\K\N+\\"}}'

usage() { echo "Usage: $0 [-p <id poller>] [-c \"<command>\"]" 1>&2; exit 1; }

not_integer() { echo "-p value : "$p" is not a id"; exit 1; }

action_command() {
        curl -s --request POST "http://localhost:8085/api/nodes/$1/core/action/command" \
             --header "Accept: application/json" \
             --header "Content-Type: application/json" \
             --data "[{\"command\": \"$2\"}]"
}

get_result() {
        curl -s --request GET "http://localhost:8085/api/nodes/$1/log/$2" \
             --header "Accept: application/json"
}

while getopts ":p:c:" o; do
    case "${o}" in
        p)
            p=${OPTARG}
             [[ "$p" =~ ^[0-9]+$ ]] || not_integer
            ;;
        c)
            c=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${p}" ] || [ -z "${c}" ]; then
    usage
fi

token=$(action_command ${p} "${c}" | grep -oP $token_regex)
echo "gorgone token : " $token
sleep 2
## {"error":"no_log","message":"No log found for token","data":[],"token":"fd90453f9bd7bdda235293064dea10d0c456a3bffcb5ffa5f77358862bf9d3e63f24d84f1527fda143e4f8ff9c50d5a033890414b97937e17b3155442fcbe730"}
json_result=$(get_result $token)
until [[ $( echo "${json_result}" | grep -oP ${stdout_regex} ) ]]
        do
        echo "no log found, waiting 2 seconds"
        sleep 2
        json_result=$(get_result ${p} $token)
done
command_output=$(echo $json_result | grep -oP $stdout_regex )
test -n "$command_output" && echo ${command_output::-4} |  sed 's#\\n#\n#g' ||  echo $json_result 
