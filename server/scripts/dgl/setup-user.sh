#!/bin/bash

# Add dgamelaunch user
useradd nemelex --shell /usr/local/sbin/dgamelaunch \
&& echo nemelex:xobeh | chpasswd \
&& mkdir -p /home/nemelex/.ssh \
&& cat "$DGL_CONF_HOME/server/keys/cao_key.pub" >> /home/nemelex/.ssh/authorized_keys \
&& chown -R nemelex:nemelex /home/nemelex/.ssh \
&& chmod 700 /home/nemelex/.ssh \
&& chmod 600 /home/nemelex/.ssh/authorized_keys \
&& cat "$DGL_CONF_HOME/server/sshd_config" >> /etc/ssh/sshd_config
