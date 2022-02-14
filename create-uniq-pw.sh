#!/usr/bin/env ansible-playbook
---
#
# ENV Variable HOSTS must be set! (ansible host definition)
#
# Ansible Inventory:
# 
#   * Add all you Hosts to "/etc/ansible/hosts" with "ini-style"
#
#
#	[mygroup]
#       XXXXX...
#       10.10.10.10
#
# 
# Usage:
#  
#   $ chmod +x <script-file>  [create-uniq-pw.sh]
#   $ HOSTS="XXXXXX" ./create-uniq-pw.sh
#   $ cat creds.csv
#   [...]
#
#
#  Exported CSV:
#
#	inventory_hostname,password
#	XXXX-nc-XXXXX-dc-1,XXXXX
#
#
#
# Needs python3 & ansible
#	
#   $ yum install rh-python36-runtime.x86_64 rh-python36 rh-python36-python.x86_64 rh-python36-python-pip.noarch rh-python36-python-setuptools.noarch rh-python36-python-devel.x86_64
#
# 
- hosts: "{{ lookup('env', 'HOSTS') | default('all', True) }}"
  remote_user: root
  gather_facts: no
#
#  Can be used as fallback if something failed
#
#  vars:
#    ssh_pubkey: XXXXXXXXX
  tasks:

  - name: create random but idempotent password
    set_fact:
      password: "{{ lookup('password', '/tmp/inv/{{ inventory_hostname }}', seed=inventory_hostname)  }}"

#
#  Uncomment if you want to use the fallback with ssh key 
#

# - name: Does /etc/ssh/sshd_config allow PubkeyAuthentication Yes ?
#    lineinfile:
#      path: /etc/ssh/sshd_config
#      regexp: '\bPubkeyAuthentication\b'
#      line: 'PubkeyAuthentication yes'

#  - name: Does /etc/ssh/sshd_config allow AuthorizedKeysFile     .ssh/authorized_keys ?
#    lineinfile:
#      path: /etc/ssh/sshd_config
#      regexp: '\bAuthorizedKeysFile\b'
#      line: 'AuthorizedKeysFile .ssh/authorized_keys'

#  - name: Insert a sshkey at the end of /root/.ssh/authorized_keys
#    lineinfile:
#      path: /root/.ssh/authorized_keys
#      line: "{{ ssh_pubkey }}"
#      #mode: 600
#      #create: yes
#      # no need to create, ansible use this 

#  - name: Restart service ssh to enable pubkeys
#    service:
#      name: sshd
#      state: restarted

  - name: Backup shadow file - /etc/shadow.bak
    copy:
      src: /etc/shadow
      dest: /etc/shadow.bak


  - name: change root password 
    user:
      name: root
      update_password: "always"
      password: "{{ password  | password_hash('sha512') }}"

  - name: make proper csv file
    lineinfile:
      create: yes
      path: all-creds.csv
      line: "'inventory_hostname','username','password','url'"
      insertbefore: BOF
      mode: 666
    delegate_to: localhost

  - name: add entry to file 
    lineinfile:
      path: all-creds.csv
      line: "'{{ inventory_hostname }}','root','{{ password }}','ssh://root@{{ inventory_hostname }}'"
    delegate_to: localhost

  - name: make proper csv file
    lineinfile:
      create: yes
      path: "{{ group_names | first }}-creds.csv"
      line: "'inventory_hostname','username','password','url'"
      insertbefore: BOF
      mode: 666
    delegate_to: localhost

  - name: add entry to file 
    lineinfile:
      path: "{{ group_names | first }}-creds.csv"
      line: "'{{ inventory_hostname }}','root','{{ password }}','ssh://root@{{ inventory_hostname }}'"
    delegate_to: localhost

  - name: "add entry to file group file - {{ group_names | first}}-creds.csv"
    lineinfile:
      path: "{{ group_names | first }}-creds.csv"
      line: "'{{ inventory_hostname }}','root','{{ password }}','ssh://root@{{ inventory_hostname }}'"
      create: yes
    delegate_to: localhost

  - name: Ensuring that wheel is able to use sudo 
    lineinfile:
      path: /etc/sudoers
      regexp: '^%wheel'
      line: '%wheel ALL=(ALL) ALL'

  - name: adding user "{{ item }}" to group wheel
    user:
      name: "{{ item }}"
      groups: wheel
      append: yes
    with_items:
    - oss


