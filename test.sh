#!/bin/bash

set -eu -o pipefail
trap 'echo "${0##*/}: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

export ANSIBLE_TIMEOUT=10
export ANSIBLE_SSH_RETRIES=0
export ANSIBLE_SSH_COMMON_ARGS='-o ConnectionAttempts=1'
export ANSIBLE_ROLES_PATH=roles
export ANSIBLE_GATHERING=explicit

vagrant up

while IFS= read -r line; do
	case $line in
		*' HostName '*     ) host=${line##* HostName } ;;
		*' Port '*         ) port=${line##* Port } ;;
		*' User '*         ) user=${line##* User } ;;
		*' IdentityFile '* ) key=${line##* IdentityFile } ;;
	esac
done < <(vagrant ssh-config)

[[ -n $host ]]
[[ -n $port ]]
[[ -n $user ]]
[[ -n $key  ]]

dir=$(mktemp -d)
trap 'rm -r -- "$dir"' EXIT

cat << EOF > "$dir/play.yml"
- name: sshjuggle
  hosts: all
  roles:
    - sshjuggle
  tasks:
    - shell: echo hi
      changed_when: false
EOF

assertrc() {
	echo "want return code: $1"
	echo "got return code:  $2"
	[[ $1 -eq $2 ]]
}

msg() {
	echo
	echo '=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#='
	echo "= $*"
	echo '=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#='
	echo
}

# =====
# =====

msg 'Test 1: Control'

cat << EOF > "$dir/hosts.yml"
all:
  hosts:
    vm:
      ansible_host: $host
      ansible_port: $port
      ansible_user: $user
      ansible_private_key_file: $key
EOF

start=$(date '+%s%N')
ansible-playbook -i "$dir/hosts.yml" "$dir/play.yml"
finish=$(date '+%s%N')

control_duration=$(( (finish - start) / 1000000 ))

msg 'Test 1 Passed'

# =====
# =====

msg 'Test 2: Performance'

cat << EOF > "$dir/hosts.yml"
all:
  hosts:
    vm:
      ansible_host: $host
      ansible_port: 12345
      ansible_user: $user
      ansible_private_key_file: $key
      sshjuggle_ports: [ 54321, $port ]
EOF

start=$(date '+%s%N')
ansible-playbook -i "$dir/hosts.yml" "$dir/play.yml"
finish=$(date '+%s%N')

duration=$(( (finish - start) / 1000000 ))

echo "control run duration: $control_duration ms"
echo "test run duration:    $duration ms"

# test performance
[[ $duration -lt $(( control_duration * 5 )) ]]

msg 'Test 2 Passed'

# =====
# =====

msg 'Test 3: Function'

cat << EOF > "$dir/hosts.yml"
all:
  hosts:
    vm:
      ansible_ssh_host: 0.0.0.0
      ansible_ssh_port: 12345
      ansible_user: nobody
      ansible_private_key_file: /dev/null
      sshjuggle_hosts: [ 1.1.1.1, null, $host ]
      sshjuggle_ports: [ 12345678, $port ]
      sshjuggle_users: [ somebody, $user ]
      sshjuggle_private_key_files: [ /nonexistent, $key ]
      sshjuggle_passwords: [ null, 12345 ]
EOF

ansible-playbook -i "$dir/hosts.yml" "$dir/play.yml"

msg 'Test 3 Passed'

# =====
# =====

msg 'Test 4: Function'

cat << EOF > "$dir/hosts.yml"
all:
  hosts:
    vm:
      ansible_port: $port
      ansible_ssh_user: $user
      ansible_ssh_password: somepassword
      sshjuggle_hosts: [ $host ]
      sshjuggle_users: [ nobody, somebody ]
      sshjuggle_private_key_files: [ /dev/null, $key, /nonexistent ]
      sshjuggle_passwords: [ anotherpassword, '' ]
      sshjuggle_gather_facts: true
EOF

ansible-playbook -i "$dir/hosts.yml" "$dir/play.yml"

msg 'Test 4 Passed'

# =====
# =====

msg 'Test 5: Fault injection'

cat << EOF > "$dir/hosts.yml"
all:
  hosts:
    vm:
      ansible_host: 0.0.0.0
      ansible_port: 12345
      ansible_user: nobody
      ansible_private_key_file: /dev/null
      sshjuggle_hosts: [ 1.1.1.1 ]
      sshjuggle_ports: [ 12345678, $port ]
      sshjuggle_users: [ somebody, $user ]
      sshjuggle_private_key_files: [ /nonexistent, $key ]
EOF

start=$(date '+%s%N')
ansible-playbook -i "$dir/hosts.yml" "$dir/play.yml" && code=$? || code=$?
finish=$(date '+%s%N')

assertrc 2 "$code"

duration=$(( (finish - start) / 1000000 ))
timeout=$(( ANSIBLE_TIMEOUT * 1000 ))

echo "ssh timeout:  $timeout ms"
echo "run duration: $duration ms"

# test the effectiveness of the ssh timeout value
[[ $duration -gt $timeout ]]
[[ $duration -lt $(( timeout * 3 )) ]]

msg 'Test 5 Passed'

# =====
# =====

msg 'Test 6: Fault injection'

cat << EOF > "$dir/hosts.yml"
all:
  hosts:
    vm:
      ansible_host: 0.0.0.0
      ansible_port: 12345
      ansible_user: nobody
      ansible_private_key_file: /dev/null
      sshjuggle_fail: false
      sshjuggle_hosts: [ 1.1.1.1 ]
      sshjuggle_ports: [ 12345678, $port ]
      sshjuggle_users: [ somebody, $user ]
      sshjuggle_private_key_files: [ /nonexistent, $key ]
EOF

ansible-playbook -i "$dir/hosts.yml" "$dir/play.yml" && code=$? || code=$?

assertrc 4 "$code"

msg 'Test 6 Passed'

# =====
# =====

msg 'All Tests Passed'
