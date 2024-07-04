#!/bin/bash

mkdir -p /etc/ssh/keys
if [ -z "$(ls -A /etc/ssh/keys)" ]; then
  ssh-keygen -t rsa -f /etc/ssh/keys/ssh_host_rsa_key -N ""
  ssh-keygen -t ecdsa -f /etc/ssh/keys/ssh_host_ecdsa_key -N ""
  ssh-keygen -t ed25519 -f /etc/ssh/keys/ssh_host_ed25519_key -N ""
fi

cp /etc/ssh/keys/* /etc/ssh
