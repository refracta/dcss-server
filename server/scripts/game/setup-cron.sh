#!/bin/bash

# Define the commands and their schedules
command1="/home/crawl-dev/dgamelaunch-config/bin/dgl update-trunk"
schedule1="*/15 * * * *"

command2="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc stoatsoup stoatsoup/master"
schedule2="0 6 * * *"

command3="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bcadrencrawl bcadrencrawl/bCrawl"
schedule3="0 7 * * *"

command4="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bcrawl bcrawl/master"
schedule4="0 8 * * *"

command5="/home/crawl-dev/dgamelaunch-config/bin/dgl compress-ttyrecs"
schedule5="*/15 * * * *"

# Check if a crontab file exists for the user, create one if not
if [ ! -e "$HOME/crontab.txt" ]; then
    touch "$HOME/crontab.txt"
fi

# Add the commands and schedules to the crontab file
{ echo "$schedule1 $command1"; } >> "$HOME/crontab.txt"
{ echo "$schedule2 $command2"; } >> "$HOME/crontab.txt"
{ echo "$schedule3 $command3"; } >> "$HOME/crontab.txt"
{ echo "$schedule4 $command4"; } >> "$HOME/crontab.txt"
{ echo "$schedule5 $command5"; } >> "$HOME/crontab.txt"

crontab -r
# Install the updated crontab file
crontab "$HOME/crontab.txt"
rm "$HOME/crontab.txt"

echo "Cron jobs have been set up:"
crontab -l
