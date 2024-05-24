# Docker Server Usage Guide

These scripts have been dockerised, with volumes to store permanent data, to allow for ease of deployment along with a very simple azure template to host the docker container on a vm.

### First Run Guide:
#### Prerequisites
* Docker

#### Steps
* build the dockerfile using `docker build --tag dgl-forks -f utils/testing-container/Dockerfile .` from the root of the git repo. Or using the `utils/build-testing-container.sh` script which does pretty much the same.
* Create the 4 volumes using `docker volume create [volume-name]` replacing volume name with one of: `versionsdb, crawl-master, dgldir, usr-games` to store persistent data.
* update the entrypoint in docker-compose.yaml from `/docker-entrypoint.sh` to `/docker-entrypoint-build-trunk` or `/docker-entrypoint-build-all`
* Run `docker-compose -f utils/testing-container/docker-compose.yaml up` from the root of the git repo to start the server and wait either a little(if trunk only around 5 min, depending on specs) or a lot of time(if building all around an hour, again depending on specs), until the server finishes building the game binaries.
* Register and play the trunk version at localhost:8080

### Subsequent runs:

* The entrypoint can be updated to just `/docker-entrypoint.sh`, so that server starts fast without rebuilding outdated binaries.
* Then, simpy run `docker-compose -f utils/testing-container/docker-compose.yaml up` from the root of the git repo to start the server, allowing it to reuse the binaries and other data already saved in the volumes.

### Controlling and debugging the server

Use `docker exec -it [container-hash] /bin/bash` to get a shell inside the container, to be able to run the commands, either locally or after ssh into the server where the container is running.

Full flow:
* `docker ps` to find the container running this server, example output:
```
CONTAINER ID   IMAGE              COMMAND                  CREATED          STATUS                    PORTS                                                                      NAMES
1c3b1928910b   dgl-forks:latest   "/docker-entrypoint.…"   19 minutes ago   Up 19 minutes (healthy)   127.0.0.1:8080->8080/tcp, 127.0.0.1:2222->22/tcp, 127.0.0.1:8081->80/tcp   testing-container-dlg-forks-server-1
```

* The Container ID is `1c3b1928910b`, only 3 letters are needed if they are unique, so we can use `docker exec -it 1c3 /bin/bash` to get a shell.
* Once bash is open in the container we can debug or execute command as if on a normal server. My most common usage is to test if the build of forks are succesful, taking a single line from the `install-crawl-versions.sh` file, like `/home/crawl-dev/dgamelaunch-config/bin/dgl update-gcc6 gnollcrawl crawl-forks/gnollcrawl/bugfix` and running it directly in the server.

* Editing shell files inside the container with vim also works, but It's best to keep this kind of configuration in code, by pushing images to a repository like dockerhub, then pulling in the new image on the server and restarting, otherwise configuration drift will occur between the production server and the git repo.

# Other issues

* When adding new forks/branches to already running server(if you want to add a totally new fork that is not in the current scripts), the data is copied from trunk files which is prefilled with data of the trunk milestones, etc. To fix this the files need to be copied, but all data needs to be removed in logfiles and similar. [Issue description](https://github.com/Rytisgit/dgamelaunch-dcss-forks-server/issues/4)
* The crontab is set up unreliably. Restarting the server seems to write multiple times to the crontab, without clearing it correctly. And it doesn't seem to activate on just invoking it with the entrypoint. Something to figure out how to have it work corrctly.
* ccache is installed, but not actually setup to be used in the compilation. Using `ccache --show-stats` shows that no files are being cached or hit when compiling. This would be good to set up for faster builds.
* Make sure that when building the image, the checked out files have the correct line endings. I've had dgl perl scripts not working due to building with windows line ending checkout when the docker was running on linux. Had to figure out by googling.

# Misc/TODO

* The ssh user and password are currently both `crawler` and it doesnt ask for a key.
* No SSL setup.
* No rebuild url hook setup.(A few servers have the `trigger-rebuild.pl` script available for devs with a login to call when they want to trigger a rebuild).
* No Mail setup for password reset(Only some server have this setup, it's mostly optional).

# dgamelaunch-config

This is a collection of scripts to manage a dgamelaunch
(http://nethackwiki.com/wiki/Dgamelaunch) install, all run from an
umbrella `dgl` script.

These are still very incomplete, WIP.

Currently available commands:

1. Update your dgamelaunch config from the repository:
   ```
   $ sudo dgl publish --confirm
   ```

2. Change a dgl user's password:
   ```
   $ sudo dgl passwd johndoe
   ```

3. Update Crawl alpha build from git master:
   ```
   $ dgl update-trunk
   ```

4. Remove stale Crawl alpha versions:
   ```
   $ dgl remove-trunks
   ```

5. Run dgl-whereis inotify daemon:
   ```
   $ sudo dgl crawl-inotify-dglwhere
   ```

   This inotify daemon monitors the dgamelaunch in-progress dirs to keep
   track of active players, and monitors their morgue directories for
   changes to their .where files. When a .where changes, the daemon reads
   it and writes a human-readable .dglwhere file in the same directory.

   You may configure dgamelaunch to show this .dglwhere information
   using the dgamelaunch extra_info_file option.

   You may also run the crawl-inotify-dglwhere script standalone (without
   the rest of the dgamelaunch-config setup) by starting it as:

      sudo -u dgl perl crawl-inotify-dglwhere.pl <dgldir> <morguedir>

Note: Some of these commands will probably change names soon.

The ultimate goal for this project is to become a one-stop shop for
all your dgamelaunch+Crawl needs, starting from installing dgamelaunch
itself

# TODO

1. `dgl install-dgl` command to fetch and install the latest dgamelaunch.

2. `dgl create-chroot` command to set up a basic chroot jail with all the
   fixtures dgamelaunch wants (dgamelaunch already has a skeleton script
   that can serve as a basis, although this is unfortunately NetHack-biased).

3. Support for installing different games, including fetching their sources
   from their respective source repositories, compiling, installing into the
   chroot, etc.
   ```
   dgl install crawl master`
   dgl install nethack 3.4.3`
   ```
   Etc.

   Installing a game should also (eventually) add a suitable entry to
   the various menu files and update the dgamelaunch config
   appropriately.

4. Support for tracking development versions of games (such as Crawl
   master) using a system similar to CDO's for creating versioned
   directories, migrating saves to newer versions, and deleting old
   versions with no remaining save games.

5. Module system so that management of say, crawl-git is a
   self-contained module. Each module should be able to contribute dgl
   commands and provide files that will be installed to the chroot or
   root filesystem.

6. Each dgl command that affects the machine or chroot should update a
   manifest. The manifest could be a file or a directory containing
   multiple manifest files.

   Given a manifest, I should be able to install dgamelaunch-config
   on a brand new machine and use one dgl command to recreate the manifest.

   For instance, something like:
   `dgl replicate-manifest <path-to-manifest>`

   The manifest should include information like this:
   * What dgamelaunch version is installed, and from where (install-dgl module)
   * chroot configuration: what binaries and libraries have been installed
     into the chroot, with the exception of game binaries, i.e. the state of
     the chroot minus games (chroot module)
   * Game configuration (handled by the various game modules)
