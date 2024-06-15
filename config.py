import logging

try:
    from collections import OrderedDict
except ImportError:
    from ordereddict import OrderedDict

dgl_mode = True

bind_nonsecure = True # Set to false to only use SSL

games_config_dir = None # Don't try to load Base.yaml

bind_pairs = (
    ("0.0.0.0", 8080),
    # ("127.0.0.1", 8080),
)

logging_config = {
    "filename": "%%CHROOT_WEBDIR%%/run/webtiles.log",
    "level": logging.DEBUG,
    "format": "%(asctime)s %(levelname)s: %(message)s"
}

password_db = "%%CHROOT_LOGIN_DB%%"

static_path = "%%CHROOT_WEBDIR%%/static"
template_path = "%%CHROOT_WEBDIR%%/templates/"

# Path for server-side unix sockets (to be used to communicate with crawl)
server_socket_path = None # Uses global temp dir

# Server name, so far only used in the ttyrec metadata
server_id = ""

# Disable caching of game data files
game_data_no_cache = False

# Watch socket dirs for games not started by the server
watch_socket_dirs = True

# Game configs
# %n in paths is replaced by the current username
# Constants for crawl binaries
STABLE_LAUNCHER = "%%DGL_CHROOT%%/bin/crawl-stable-launcher.sh"
GIT_LAUNCHER = "%%DGL_CHROOT%%/bin/crawl-git-launcher.sh"

template_game = {
    "crawl_binary": STABLE_LAUNCHER,
    "send_json_options": True,
    "rcfile_path": "%%CHROOT_RCFILESDIR%%/crawl-{}/",
    "macro_path": "%%CHROOT_RCFILESDIR%%/crawl-{}/",
    "morgue_path": "%%CHROOT_MORGUEDIR%%/%n/",
    "morgue_url": "CONFIG_MORGUE_URL",
    "inprogress_path": "%%CHROOT_INPROGRESSDIR%%/crawl-{}/",
    "ttyrec_path": "%%CHROOT_TTYRECDIR%%/%n/",
    "socket_path": "%%CHROOT_WEBDIR%%/sockets",
}


def create_game(game_key, overrides=None):
    if overrides is None:
        overrides = {}

    version, inprogress = game_key, game_key
    if "version" in overrides:
        version = overrides["version"]
        inprogress =  f"{version}"
    if "inprogress" in overrides and overrides['inprogress']:
        inprogress = f"{version}-{overrides['inprogress']}"

    config = template_game.copy()
    config.update(
        {
            "name": game_key,
            "rcfile_path": config["rcfile_path"].format(version),
            "macro_path": config["macro_path"].format(version),
            "inprogress_path": config["inprogress_path"].format(inprogress),
        }
    )
    del overrides['inprogress']
    del overrides['version']

    config.update(overrides)
    return game_key, config


version_range = range(11, 31 + 1)
versions = list(version_range)
mods = [
    {"name": None, "suffix": "", "options": [], "inprogress": None},
    {"name": "Tutorial", "suffix": "-tutorial", "options": ["-tutorial"], "inprogress": "tutorial"},
    {"name": "Sprint", "suffix": "-sprint", "options": ["-sprint"], "inprogress": "sprint"},
    {"name": "Seeded", "suffix": "-seeded", "options": ["-seed"], "inprogress": "seed"},
    {"name": "Descent", "suffix": "-descent", "options": ["-descent"], "inprogress": "descent"},
    {"name": "Zot Defense", "suffix": "-zd", "options": ["-zotdef"], "inprogress": "zotdef"}
]

forks_data = [
    ("dcssca", {"name": "DCSS Circus Animals", "allowed_mods": ["Tutorial", "Sprint"]}),
    ("hellcrawl", {"name": "HellCrawl", "allowed_mods": ["Tutorial", "Sprint"]}),
    ("gnollcrawl", {"name": "GnollCrawl", "allowed_mods": ["Tutorial", "Sprint"]}),
    ("bloatcrawl2", {"name": "BloatCrawl 2", "allowed_mods": ["Tutorial", "Sprint", "Seeded"]}),
    ("gooncrawl", {"name": "GoonCrawl", "allowed_mods": ["Tutorial", "Sprint"]}),
    ("xcrawl", {"name": "X-Crawl", "allowed_mods": ["Tutorial", "Sprint"]}),
    ("stoatsoup", {"name": "Stoat Soup", "allowed_mods": ["Tutorial", "Sprint"]}),
    ("bcadrencrawl", {"name": "BcadrenCrawl", "allowed_mods": ["Tutorial", "Sprint", "Seeded"]}),
    ("kimchicrawl", {"name": "KimchiCrawl", "allowed_mods": ["Tutorial", "Sprint", "Seeded"]}),
    ("addedcrawl", {"name": "AddedCrawl", "allowed_mods": ["Tutorial", "Sprint", "Seeded"]})
]
variants = [fork[0] for fork in forks_data] + [f"0.{i}" for i in versions]

trunk = [
    create_game(
        f"dcss-git{mod['suffix']}",
        {
            "name": mod['name'] if mod['name'] else "DCSS trunk",
            "version": "git",
            "crawl_binary": GIT_LAUNCHER,
            "options": mod['options'],
            "inprogress": mod['inprogress']
        }
    )
    for mod in mods
    if (mod['name'] != "Zot Defense")
]

stable_versions = [
    create_game(
        f"dcss-0.{version}{mod['suffix']}",
        {
            "name": mod['name'] if mod['name'] else f"DCSS 0.{version}",
            "version": f"0.{version}",
            "options": mod['options'],
            "pre_options": [f"0.{version}"],
            "inprogress": mod['inprogress']
        }
    )
    for version in reversed(version_range)
    for mod in mods
    if (mod['name'] != "Seeded" or version >= 23) and
       (mod['name'] != "Descent" or version >= 31) and
       (mod['name'] != "Zot Defense" or version <= 15)
]

forks = [
    create_game(
        f"{key}{mod['suffix']}",
        {
            "name": mod['name'] if mod['name'] else data['name'],
            "version": key,
            "pre_options": [key],
            "options": mod['options'],
            "inprogress": mod['inprogress']
        }
    )
    for key, data in forks_data
    for mod in mods
    if mod['name'] is None or mod['name'] in data['allowed_mods']
]

# Combine all game lists into one
games = OrderedDict(trunk + stable_versions + forks)

dgl_status_file = "%%CHROOT_WEBDIR%%/run/status"
forks_milestones = [
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-dcssca/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-hellcrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-gnollcrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-bloatcrawl2/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-gooncrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-xcrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-stoatsoup/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-bcadrencrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-kimchicrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-addedcrawl/saves/milestones"
]

version_milestones = [
    f"%%CHROOT_CRAWL_BASEDIR%%/crawl-0.{version}/saves/milestones"
    for version in version_range
]

trunk_milestones = [
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones",
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones-tutorial",
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones-sprint",
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones-descent"
]
milestone_file = [*forks_milestones, *version_milestones, *trunk_milestones]

# Set to None not to read milestones

status_file_update_rate = 5

recording_term_size = (80, 24)

max_connections = 500

# Script to initialize a user, e.g. make sure the paths
# and the rc file exist. This is not done by the server
# at the moment.
init_player_program = "%%DGL_CHROOT%%/bin/init-webtiles.sh"

ssl_options = None # No SSL
# in a production server, you really do want to use SSL...
# ssl_options = {
#    "certfile": "/etc/ssl/private/SERVER.crt",
#    "keyfile": "/etc/ssl/private/SERVER.key",
#    "ca_certs": "/etc/ssl/private/cas.pem"
#}

ssl_bind_pairs = tuple(
    (pair[0], 443) for pair in bind_pairs
)

connection_timeout = 600
max_idle_time = 5 * 60 * 60

# Seconds until stale HTTP connections are closed
# This needs a patch currently not in mainline tornado.
http_connection_timeout = 600

kill_timeout = 10 # Seconds until crawl is killed after HUP is sent

nick_regex = r"^[a-zA-Z0-9]{3,20}$"
max_passwd_length = 20

allow_password_reset = False # Set to true to allow users to request a password reset email. Some settings must be properly configured for this to work

# Set to the primary URL where a player would reach the main lobby
# For example: "http://crawl.akrasiac.org/"
# This is required for for password reset, as it will be the base URL for
# recovery URLs.
lobby_url = None

# Proper SMTP settings are required for password reset to function properly.
# if smtp_host is anything other than `localhost`, you may need to adjust the
# timeout settings (see server.py, calls to ioloop.set_blocking_log_threshold).
# Ideally, test out these settings carefully in a non-production setting
# before enabling this, as there's a bunch of ways for this to go wrong and you
# don't want to get your SMTP server blacklisted.
smtp_host = "localhost"
smtp_port = 25
smtp_use_ssl = False
smtp_user = "" # set to None for no auth
smtp_password = ""
smtp_from_addr = "noreply@crawl.example.org" # The address from which automated
# emails will be sent

# crypt() algorithm, e.g. "1" for MD5 or "6" for SHA-512; see crypt(3).
# If false, use traditional DES (but then only the first eight characters
# are significant).
crypt_algorithm = "6"
# If crypt_algorithm is true, the length of the salt string to use. If
# crypt_algorithm is false, a two-character salt is used.
crypt_salt_length = 16

login_token_lifetime = 7 # Days

try:
    uid = int("%%DGL_UID%%")
    # If this is not None, the server will setuid to that (numeric) id
except ValueError:
    uid = -1

try:
    gid = int("%%DGL_GID%%")  # after binding its sockets.
except ValueError:
    gid = -1

umask = None # e.g. 0077

chroot = "%%DGL_CHROOT%%"

pidfile = "%%CHROOT_WEBDIR%%/run/webtiles.pid"
daemon = True # If true, the server will detach from the session after startup

# Set to a URL with %s where lowercased player name should go in order to
# hyperlink WebTiles spectator names to their player pages.
# For example: "http://crawl.akrasiac.org/scoring/players/%s.html"
# Set to None to disable player page hyperlinks
player_url = "http://crawl.akrasiac.org/scoring/players/%s.html"

# Only for development:
# Disable caching of static files which are not part of game data.
no_cache = False
# Automatically log in all users with the username given here.
autologin = None
