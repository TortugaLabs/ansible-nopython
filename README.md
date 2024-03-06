# ansible-nopython

Functionality to reduce dependancy of python for Ansible managed nodes

The code here is derived from [gekmihesg/ansible-openwrt][ao].

It is no longer a role, but a set of modules and a monkeypatching
[var_plugin][avp].  As such, dependancies to [OpenWRT][ow]
have been completely removed.  And it does not try to configure
anything in particular, but just give functionality so that
you can use [ansible][aa] without needing [python][py] on
managed nodes.

## Installation

Copy the files in this repository and either configure `ansible.cfg`
or set environment variables:

- `ansible.cfg`:
  ```yaml
  DEFAULT_MODULE_PATH=path/to/src/library
  DEFAULT_VARS_PLUGINN_PATH=path/to/src/vars_plugins
  ```
- environment variables:
  - `ANSIBLE_LIBRARY=`_path/to/src/library_
  - `ANSIBLE_VAR_PLUGINS=`_path/to/src/vars_plugins_


Afterwards, it is a matter of creating an inventory and placing
hosts that do not have [python][py] installed in a `nopython`
group.

```ini
[nopython]
host1
host2
```

## Requirements

Some modules optionally require a way to generate SHA1 hashes or
encode data Base64.

In case of Base64, there is a very slow `hexdump | awk` implementation
included.

For SHA1 there is no workaround.

The modules will try to find usable system commands for SHA1
(`sha1sum`, `openssl`) and Base64 (`base64`, `openssl`, workaround)
when needed. If no usable commands are found, most things will still
work, but the fetch module for example has to be run with
`validate_checksum: no`, will always download the file and return
`changed: yes`.

Therefore it is recommended to install `coreutils-sha1sum` and
`coreutils-base64`, if the commands are not already provided by
busybox.

## Modules

The following modules have been imported from [ansible-openwrt][ao]:

 * command
 * copy
 * fetch (implicit)
 * file
 * lineinfile
 * nohup (new)
 * opkg
 * ping
 * setup
 * shell (implicit)
 * slurp
 * stat
 * service
 * sysctl
 * template (implicit)

These modules were added:

 * apk
 * modprobe
 * service_facts

These packages were removed as I found them too [openwrt][ow]
specific.

 * uci (new)
 * wait\_for\_connection (implicit)

## Example playbook

Inventory:

```ini
[aps]
ap1.example.com
ap2.example.com
ap3.example.com

[routers]
router1.example.com

[nopython:children]
aps
routers
```

Playbook:

```yaml
- hosts: all
  tasks:
    - name: copy authorized keys
      copy:
        src: authorized_keys
        dest: /root/.ssh/authorized_keys
```

Running the modules outside of a playbook is possible like this:

```bash
$ export ANSIBLE_LIBRARY=~/path/to/src/library
$ export ANSIBLE_VARS_PLUGINS=~/path/to/src/vars_plugins
$ ansible -i inventory.ini -m setup all
```

## Extensions

The `command` module was extended to include a parameter
`no_change_rc` which tales a single `int`.  If the command
exits with this return code, it will report the execute to
not generate changes.  It replaces this type of code:

```yaml
- name: Exec sh command
  shell:
    cmd: "echo ''; exit 254;"
  register: result
  failed_when: result.rc != 0 and result.rc != 254
  changed_when: result.rc != 254
```

## Developing

Writing custom modules for this framework isn't too hard.
The modules are wrapped into a wrapper script, that provides
some common functions for parameter parsing, json handling, response
generation, and some more.

All modules must match `nopython_<module_name>.sh`. If module\_name
is not one of Ansibles core modules, there must also be a
`<module_name>.py`. This does not have to have any functionality
(it may have some for non OpenWRT systems) and can contain the
documentation.

## License

GNU General Public License v3.0 (see [License][gpl])

Portions are Copyright (c) 2017-2021 Markus Weippert also under
the GNU General Public License v3.0 ([License][gpl])

  [gpl]: https://www.gnu.org/licenses/gpl-3.0.txt
  [ao]: https://github.com/gekmihesg/ansible-openwrt
  [avp]: https://docs.ansible.com/ansible/latest/plugins/vars.html
  [ow]: https://openwrt.org/
  [aa]: https://www.ansible.com/
  [py]: https://www.python.org/
