#!/bin/bash

# Define the commands and their schedules
command1="/home/crawl-dev/dgamelaunch-config/bin/dgl update-trunk"
schedule1="*/15 * * * *"

command2="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc stoatsoup stoatsoup/master"
schedule1="*/15 * * * *"

command3="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bcadrencrawl bcadrencrawl/bCrawl"
schedule1="*/15 * * * *"

# Check if a crontab file exists for the user, create one if not
if [ ! -e "$HOME/crontab.txt" ]; then
    touch "$HOME/crontab.txt"
fi

# Add the commands and schedules to the crontab file
{ echo "$schedule1 $command1"; } >> "$HOME/crontab.txt"
{ echo "$schedule2 $command2"; } >> "$HOME/crontab.txt"
{ echo "$schedule3 $command3"; } >> "$HOME/crontab.txt"

crontab -r
# Install the updated crontab file
crontab "$HOME/crontab.txt"
rm "$HOME/crontab.txt"

echo "Cron jobs have been set up:"
crontab -l
