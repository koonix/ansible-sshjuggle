#!/usr/bin/env bash
set -eu -o pipefail

: ${SJ_RETRIES:='0'}
: ${SJ_SSH_EXECUTABLE:='ssh'}
: ${SJ_SSH_CONNECT_TIMEOUT:='10'}

readarray -t hosts <<< "${SJ_HOSTS:-}"
readarray -t ports <<< "${SJ_PORTS:-}"
readarray -t users <<< "${SJ_USERS:-}"
readarray -t keys  <<< "${SJ_KEYS:-}"

readarray -t passfiles <<< "$(
	if [[ -n ${SJ_PASSWORDS_DIR:-} ]]; then
		for f in "$SJ_PASSWORDS_DIR"/*; do
			if [[ -e $f ]]; then
				printf '%s\n' "$f"
			fi
		done
	fi
)"

# sleep function using bash builtins
exec {sleepfd}<> <(:)
rsleep() { read -t "$1" -u "$sleepfd" ||: ;}

while IFS= read -r result; do
	case $result in
		sshjuggle-success*)
			echo "$result"
			pkill --session=0 --ignore-ancestors ||:
			exit
		;;
	esac
done < <(

	for host in "${hosts[@]}"; do
	for port in "${ports[@]}"; do
	for user in "${users[@]}"; do
	for key  in "${keys[@]}";  do
	for passfile in "${passfiles[@]}"; do

		# run at most 100 jobs in parallel
		while [[ $(jobs -p | wc -l) -ge 100 ]]; do
			rsleep 0.1
		done

		(
			retries=0
			while :; do

				timeout 10m \
					${passfile:+sshpass -f "$passfile" ${SJ_SSHPASS_PROMPT:+-P "$SJ_SSHPASS_PROMPT"}} \
					"$SJ_SSH_EXECUTABLE" \
					-o StrictHostKeyChecking=no \
					-o ControlPath=none \
					-o ConnectionAttempts=1 \
					${SJ_SSH_ARGS:-} \
					${SJ_SSH_EXTRA_ARGS:-} \
					${SJ_SSH_COMMON_ARGS:-} \
					-o ConnectTimeout="$SJ_SSH_CONNECT_TIMEOUT" \
					${port:+-o Port="$port"} \
					${user:+-o User="$user"} \
					${key:+-o IdentityFile="$key"} \
					"$host" : \
					&& code=$? || code=$?

				case $code in
					124) ;; # timeout
					255) ;; # ssh failure
					0)
						printf '%s\t' \
							'sshjuggle-success' \
							"$host" \
							"$port" \
							"$user" \
							"$key" \
							"$passfile"
						echo
					;;
					*) exit "$code" ;;
				esac

				retries=$(( retries + 1 ))
				if [[ $retries -gt $SJ_RETRIES ]]; then
					break
				fi

				rsleep 1
			done
		) &

	done
	done
	done
	done
	done

	wait
)
