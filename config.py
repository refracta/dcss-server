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
STABLE_LAUNCHER = "/bin/crawl-stable-launcher.sh"
GIT_LAUNCHER = "/bin/crawl-git-launcher.sh"

template_game = {
    "crawl_binary": STABLE_LAUNCHER,
    "send_json_options": True,
    "rcfile_path": "%%CHROOT_RCFILESDIR%%/crawl-{}/",
    "macro_path": "%%CHROOT_RCFILESDIR%%/crawl-{}/",
    "morgue_path": "%%CHROOT_MORGUEDIR%%/%n/",
    "morgue_url": "https://archive.nemelex.cards/morgue/%n/",
    "inprogress_path": "%%CHROOT_INPROGRESSDIR%%/crawl-{}/",
    "ttyrec_path": "%%CHROOT_TTYRECDIR%%/%n/",
    "socket_path": "%%CHROOT_WEBDIR%%/sockets",
}


def create_game(game_key, overrides=None):
    if overrides is None:
        overrides = {}

    config = template_game.copy()
    config.update({
        "name": overrides.get("name", game_key.replace('-', ' ').title()),
        "rcfile_path": config["rcfile_path"].format(game_key),
        "macro_path": config["macro_path"].format(game_key),
        "inprogress_path": config["inprogress_path"].format(game_key)
    })
    config.update(overrides)

    return game_key, config


games = OrderedDict([
    create_game("dcssca", {"name": "DCSS Circus Animals"}),
    create_game("hellcrawl", {"name": "HellCrawl"}),
    create_game("gnollcrawl", {"name": "GnollCrawl"}),
    create_game("bloatcrawl2", {"name": "BloatCrawl 2"}),
    create_game("gooncrawl", {"name": "GoonCrawl"}),
    create_game("xcrawl", {"name": "X-Crawl"}),
    create_game("stoatsoup", {"name": "Stoat Soup"}),
    create_game("kimchicrawl", {"name": "KimchiCrawl"}),
    create_game("bcadrencrawl", {"name": "BcadrenCrawl"}),
    create_game("dcss-git", {
        "name": "DCSS trunk",
        "crawl_binary": GIT_LAUNCHER
    }),
    create_game("dcss-git-descent", {
        "name": "DCSS Descent!",
        "crawl_binary": GIT_LAUNCHER,
        "pre_options": ["descent"]
    }),
    create_game("dcss-git-sprint", {
        "name": "Sprint trunk",
        "crawl_binary": GIT_LAUNCHER,
        "pre_options": ["sprint"]
    }),
    create_game("dcss-git-tutorial", {
        "name": "Tutorial trunk",
        "crawl_binary": GIT_LAUNCHER,
        "pre_options": ["tutorial"]
    }),
    *[create_game(f'dcss-0.{version}', {"name": f'DCSS 0.{version}'}) for version in range(11, 31 + 1)]
])
dgl_status_file = "%%CHROOT_WEBDIR%%/run/status"

# Set to None not to read milestones
milestone_file = [
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-dcssca/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-hellcrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-gnollcrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-bloatcrawl2/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-gooncrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-xcrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-stoatsoup/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-kimchicrawl/saves/milestones",
    "%%CHROOT_CRAWL_BASEDIR%%/crawl-bcadrencrawl/saves/milestones",
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones",
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones-tutorial",
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones-sprint",
    "%%CHROOT_CRAWL_GAMEDIR%%/saves/milestones-descent"
]

status_file_update_rate = 5

recording_term_size = (80, 24)

max_connections = 500

# Script to initialize a user, e.g. make sure the paths
# and the rc file exist. This is not done by the server
# at the moment.
init_player_program = "/bin/init-webtiles.sh"

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

uid = int("%%DGL_UID%%")  # If this is not None, the server will setuid to that (numeric) id
gid = int("%%DGL_GID%%")  # after binding its sockets.

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
