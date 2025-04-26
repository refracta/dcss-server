#!/bin/bash

# Define the commands and their schedules
command1="env - \$(cat /proc/1/environ | tr '\\0' '\\n') /home/crawl-dev/dgamelaunch-config/bin/dgl update-trunk >> /home/crawl-dev/logs/trunk.log 2>&1"
schedule1="*/15 * * * *"

command2="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc stoatsoup stoatsoup/master >> /home/crawl-dev/logs/stoatsoup.log 2>&1"
schedule2="0 6 * * *"

command3="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bcadrencrawl bcadrencrawl/bCrawl >> /home/crawl-dev/logs/bcadrencrawl.log 2>&1"
schedule3="0 7 * * *"

command4="/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc bcrawl bcrawl/master >> /home/crawl-dev/logs/bcrawl.log 2>&1"
schedule4="0 8 * * *"

command5="/home/crawl-dev/dgamelaunch-config/bin/dgl compress-ttyrecs"
schedule5="*/15 * * * *"

command6="/home/crawl-dev/dgamelaunch-config/bin/dgl update-stable 0.33 >> /home/crawl-dev/logs/0.33.log 2>&1"
schedule6="0 2-23/3 3-17 5 *"

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
{ echo "$schedule6 $command6"; } >> "$HOME/crontab.txt"

crontab -r
# Install the updated crontab file
crontab "$HOME/crontab.txt"
rm "$HOME/crontab.txt"

echo "Cron jobs have been set up:"
crontab -l
