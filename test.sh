#!/bin/bash

set -eu -o pipefail
trap 'echo "${0##*/}: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

export ANSIBLE_TIMEOUT=10
export ANSIBLE_SSH_RETRIES=0
export ANSIBLE_SSH_COMMON_ARGS='-o ConnectionAttempts=1'
export ANSIBLE_ROLES_PATH=roles
export ANSIBLE_GATHERING=explicit

vagrant up

host1='' host2=''
port1='' port2=''
user1='' user2=''
key1=''  key2=''

while IFS= read -r line; do
	case $line in
		*' HostName '*     ) val=${line##* HostName };     [[ -z $host1 ]] && host1=$val || host2=$val ;;
		*' Port '*         ) val=${line##* Port };         [[ -z $port1 ]] && port1=$val || port2=$val ;;
		*' User '*         ) val=${line##* User };         [[ -z $user1 ]] && user1=$val || user2=$val ;;
		*' IdentityFile '* ) val=${line##* IdentityFile }; [[ -z $key1  ]] && key1=$val  || key2=$val  ;;
	esac
done < <(vagrant ssh-config)

[[ -n $host1 ]]; [[ -n $host2 ]]
[[ -n $port1 ]]; [[ -n $port2 ]]
[[ -n $user1 ]]; [[ -n $user2 ]]
[[ -n $key1  ]]; [[ -n $key2  ]]

dir=$(mktemp -d)
trap 'rm -r -- "$dir"' EXIT

cat << EOF > "$dir/play.yml"
- name: sshjuggle
  hosts: all
  roles:
    - sshjuggle
  tasks:
    - ansible.builtin.shell:
        cmd: echo success
      changed_when: false
EOF

mkdir "$dir/hosts"

cat << EOF > "$dir/hosts/vm2.yml"
all:
  hosts:
    vm2:
      ansible_host: $host2
      ansible_port: 12345
      ansible_user: $user2
      ansible_private_key_file: $key2
      sshjuggle_ports: [ 54321, $port2 ]
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

cat << EOF > "$dir/hosts/vm1.yml"
all:
  hosts:
    vm1:
      ansible_host: $host1
      ansible_port: $port1
      ansible_user: $user1
      ansible_private_key_file: $key1
EOF

start=$(date '+%s%N')
ansible-playbook -i "$dir/hosts" "$dir/play.yml"
finish=$(date '+%s%N')

control_duration=$(( (finish - start) / 1000000 ))

msg 'Test 1 Passed'

# =====
# =====

msg 'Test 2: Performance'

cat << EOF > "$dir/hosts/vm1.yml"
all:
  hosts:
    vm1:
      ansible_host: $host1
      ansible_port: 12345
      ansible_user: $user1
      ansible_private_key_file: $key1
      sshjuggle_ports: [ 54321, $port1 ]
EOF

start=$(date '+%s%N')
ansible-playbook -i "$dir/hosts" "$dir/play.yml"
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

cat << EOF > "$dir/hosts/vm1.yml"
all:
  hosts:
    vm1:
      ansible_ssh_host: 0.0.0.0
      ansible_ssh_port: 12345
      ansible_user: nobody
      ansible_private_key_file: /dev/null
      sshjuggle_hosts: [ 1.1.1.1, null, $host1 ]
      sshjuggle_ports: [ 12345678, $port1 ]
      sshjuggle_users: [ somebody, $user1 ]
      sshjuggle_private_key_files: [ /nonexistent, $key1 ]
      sshjuggle_passwords: [ null, 12345 ]
EOF

ansible-playbook -i "$dir/hosts" "$dir/play.yml"

msg 'Test 3 Passed'

# =====
# =====

msg 'Test 4: Function'

cat << EOF > "$dir/hosts/vm1.yml"
all:
  hosts:
    vm1:
      ansible_port: $port1
      ansible_ssh_user: $user1
      ansible_ssh_password: somepassword
      sshjuggle_hosts: [ $host1 ]
      sshjuggle_users: [ nobody, somebody ]
      sshjuggle_private_key_files: [ /dev/null, $key1, /nonexistent ]
      sshjuggle_passwords: [ anotherpassword, '' ]
      sshjuggle_gather_facts: true
EOF

ansible-playbook -i "$dir/hosts" "$dir/play.yml"

msg 'Test 4 Passed'

# =====
# =====

msg 'Test 5: Fault injection'

cat << EOF > "$dir/hosts/vm1.yml"
all:
  hosts:
    vm1:
      ansible_host: 0.0.0.0
      ansible_port: 12345
      ansible_user: nobody
      ansible_private_key_file: /dev/null
      sshjuggle_hosts: [ 1.1.1.1 ]
      sshjuggle_ports: [ 12345678, $port1 ]
      sshjuggle_users: [ somebody, $user1 ]
      sshjuggle_private_key_files: [ /nonexistent, $key1 ]
EOF

start=$(date '+%s%N')
ansible-playbook -i "$dir/hosts" "$dir/play.yml" && code=$? || code=$?
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

cat << EOF > "$dir/hosts/vm1.yml"
all:
  hosts:
    vm1:
      ansible_host: 0.0.0.0
      ansible_port: 12345
      ansible_user: nobody
      ansible_private_key_file: /dev/null
      sshjuggle_fail: false
      sshjuggle_hosts: [ 1.1.1.1 ]
      sshjuggle_ports: [ 12345678, $port1 ]
      sshjuggle_users: [ somebody, $user1 ]
      sshjuggle_private_key_files: [ /nonexistent, $key1 ]
EOF

ansible-playbook -i "$dir/hosts" "$dir/play.yml" && code=$? || code=$?

assertrc 4 "$code"

msg 'Test 6 Passed'

# =====
# =====

msg 'All Tests Passed'

# vim:noexpandtab
