#!/bin/bash
# don't commit this file after adding private settings or credentials.
# The repository contains only this inactive template.

set -e

# Uncomment and fill in the settings below on the server.
# setup-cnc-config.sh runs this before dgl publish, so edit the source config.
# Use the test server's own URL when configuring the test server.
# Escape shell and sed metacharacters in replacement values.
# sed -i \
#   -e 's|^allow_password_reset = .*|allow_password_reset = True|' \
#   -e 's|^lobby_url = .*|lobby_url = "https://crawl.nemelex.cards/"|' \
#   -e 's|^smtp_host = .*|smtp_host = "smtp.example.org"|' \
#   -e 's|^smtp_port = .*|smtp_port = 465|' \
#   -e 's|^smtp_use_ssl = .*|smtp_use_ssl = True|' \
#   -e 's|^smtp_user = .*|smtp_user = "REPLACE_WITH_SMTP_USER"|' \
#   -e 's|^smtp_password = .*|smtp_password = "REPLACE_WITH_SMTP_PASSWORD"|' \
#   -e 's|^smtp_from_addr = .*|smtp_from_addr = "noreply@nemelex.cards"|' \
#   "$DGL_CONF_HOME/config.py"
