# ansible-sshjuggle

Ansible collection that comes with a role
for finding a working set of ssh connection parameters
amongst multiple specified parameters.

## Roles

### sshjuggle

This role finds a working set of ssh parameters
by trying out Ansible's [regular ssh parameters](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ssh_connection.html)
*and* the parameters specified in this role's variables.

sshjuggle tests all possible combinations of the connection parameters in parallel,
and the role proceeds with updating the connection parameters to the working ones
as soon as a working set of parameters are found.

Since Ansible tries to connect to the host
and gather facts before any roles are applied,
Ansible's [gathering option](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#default-gathering)
should be set to `explicit`.

This role will trigger fact gathering after setting the connection parameters,
a behaviour that can be controlled by the `sshjuggle_gather_facts` variable.

| Variable                                          | Default      | Description |
|---------------------------------------------------|--------------|-------------|
| `sshjuggle_ports`                                 | `[ 22 ]`     | Ports to try in addition to the [default port parameter](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ssh_connection.html#parameter-port). |
| `sshjuggle_hosts`                                 | `[]`         | Hosts to try in addition to the [default host parameter](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ssh_connection.html#parameter-host). |
| `sshjuggle_users`                                 | `[]`         | Users to try in addition to the [default user parameter](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ssh_connection.html#parameter-remote_user). |
| `sshjuggle_passwords`                             | `[]`         | Passwords to try in addition to the [default password parameter](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ssh_connection.html#parameter-password). |
| `sshjuggle_private_key_files`                     | `[]`         | Private key files to try in addition to the [default private key file parameter](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ssh_connection.html#parameter-private_key_file). |
| `sshjuggle_gather_facts`                          | `true`       | Whether to trigger Ansible's fact gathering at the end of the role. |
| `sshjuggle_fail`                                  | `true`       | Whether to fail if sshjuggle fails to connect to the host. |

#### Usage

Example [requirements.yml](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html#installing-roles-and-collections-from-the-same-requirements-yml-file]) file:

```yaml
collections:
  - name: https://github.com/koonix/ansible-sshjuggle
    type: git
    version: 0.1.2
```

Example usage in a playbook:

```yaml
- name: Roles
  hosts: all
  roles:
    - { role: koonix.sshjuggle.sshjuggle, tags: always }
    - ...
```
