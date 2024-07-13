#! /usr/bin/perl
#
# Allows DGL admin users to trigger rebuilds of trunk or stable.

use CGI qw/:standard/;
use MIME::Base64;

use DBI;

my $DGL = "/home/crawl-dev/dgamelaunch-config/bin/dgl";
my $DB = "%%LOGIN_DB%%";
my $CONTENT_DIR = '%%SAVE_DUMPDIR%%/';

my $AUTH_REALM = 'Developer account';

sub request_auth() {
  print(header(-type => 'text/html',
               -status => '401 Authorization Required',
               -WWW_Authenticate => "Basic realm=\"$AUTH_REALM\""),
        start_html('Rebuild trigger'),
        p('Must authenticate to trigger rebuilds.'),
        end_html);
  return undef;
}

sub match_password($$) {
  my ($plain, $crypt) = @_;
  my $cc = crypt($plain, $crypt);
  return crypt($plain, $crypt) eq $crypt;
}

sub valid_user($$) {
  my ($user, $password) = @_;
  my $db = DBI->connect("dbi:SQLite:dbname=$DB", '', '')
    or die "Can't open auth db: $DB\n";
  my $st = $db->prepare(<<QUERY);
SELECT username, password FROM dglusers
WHERE username=? AND (flags & 1) = 1;
QUERY
  $st->execute($user);
  my $row = $st->fetchrow_arrayref;

  # Should have at least one row.
  return defined($row) && match_password($password, $row->[1]);
}

sub valid_auth($) {
  my $header = shift;
  return unless $header =~ s/^Basic //;
  my $decoded = decode_base64($header);
  my ($user, $password) = $decoded =~ /(.*?):(.*)/;
  valid_user($user, $password)
}

sub authenticate() {
  my $auth_header = http('Authorization');
  return request_auth() unless $auth_header && valid_auth($auth_header);
  1
}

sub file_bytes($) {
  my $file = shift;
  open my $inf, '<', $file;
  binmode $inf;
  my $content = do { local $/; <$inf> };
  close $inf;
  $content
}

sub serve_file() {
  my ($file) = param('file');

  my $absfile = "$CONTENT_DIR/$file";
  if ($file =~ /[.]{2}/ ||
      $file !~ /^[a-zA-Z0-9._-]+$/ ||
      $file !~ /\.(?:tar\.bz2|cs)$/ ||
      !-r $absfile)
  {
    print(header(-status => '404 Not Found'),
          start_html,
          p("Could not find $absfile"),
          end_html);
    return;
  }

  print(header(-type => 'application/octet-stream'),
        file_bytes($absfile));
}

sub do_update($;$) {
  my $branch = shift;

  my $specific = $_[0] or $branch;

  local $| = 1;
  print(header(-type => 'text/html',
               -WWW_Authenticate => "Basic realm=\"$AUTH_REALM\""),
        start_html('Rebuild trigger'),
        p("Rebuilding $specific. . ."));
  print "<pre>";
  open my $olderr, ">&STDERR";
  open STDERR, ">&STDOUT";
  system(qw(sudo -u crawl-dev), $DGL, "update-$branch", @_);
  print "</pre>";
  if ($?) {
    my $msg;
    if ($? == -1) {
      $msg = "could not execute: $?";
    } elsif ($? & 0xff) {
      $msg = "signal " . ($? & 0xff);
    } else {
      $msg = "returned " . ($? >> 8);
    }
    print p({-style => 'background-color: #ffcccc;'},
            "Failed: $msg");
  } else {
    print p("Done!");
  }
  print end_html;
  open STDERR, $olderr;
}

sub do_prompt(@) {
  print(header(-type => 'text/html',
               -WWW_Authenticate => "Basic realm=\"$AUTH_REALM\""),
        start_html('Rebuild trigger'),
        start_form,
        p('Select a version'),
        popup_menu(-name => 'v', -values => [ @_ ]),
        submit,
        end_form,
        end_html);
}

sub do_fail($) {
  my $msg = shift;
  print(header(-type => 'text/html',
               -status => '403 Forbidden',
               -WWW_Authenticate => "Basic realm=\"$AUTH_REALM\""),
        start_html('Rebuild trigger'),
        start_form,
        p({-style=>'background-color: #ffcccc;'}, $msg),
        popup_menu(-name => 'v', -values => @_),
        submit,
        end_form,
        end_html);
}

sub main() {
  return unless authenticate();
  my $ver = param('v');

  if (not $ver) {
    do_prompt 'trunk', 'dcssca', 'hellcrawl', 'gnollcrawl', 'bcrawl', 'bloatcrawl2', 'gooncrawl', 'xcrawl', 'stoatsoup', 'bcadrencrawl', 'kimchicrawl', 'addedcrawl', map { "0.$_" } (11 .. 31);
  } elsif ($ver eq 'trunk') {
    do_update 'trunk';
  } elsif ($ver =~ /^0\.\d+$/) {
    do_update 'stable', $ver;
  } elsif ($ver eq 'dcssca') {
    do_update 'gcc', 'dcssca crawl-forks/dcssca/bugfix 6';
  } elsif ($ver eq 'hellcrawl') {
    do_update 'gcc', 'hellcrawl crawl-forks/hellcrawl/bugfix 6';
  } elsif ($ver eq 'gnollcrawl') {
    do_update 'gcc', 'gnollcrawl crawl-forks/gnollcrawl/bugfix 6';
  } elsif ($ver eq 'bcrawl') {
    do_update 'gcc', 'bcrawl bcrawl/master';
  } elsif ($ver eq 'bloatcrawl2') {
    do_update 'gcc', 'bloatcrawl2 bloatcrawl2/master 7';
  } elsif ($ver eq 'stoatsoup') {
    do_update 'gcc', 'stoatsoup stoatsoup/master';
  } elsif ($ver eq 'gooncrawl') {
    do_update 'gcc', 'gooncrawl gooncrawl/gooncrawl_stable 7';
  } elsif ($ver eq 'xcrawl') {
    do_update 'gcc', 'xcrawl crawl-forks/xcrawl/bugfix 7';
  } elsif ($ver eq 'bcadrencrawl') {
    do_update 'gcc', 'bcadrencrawl crawl-forks/bcadrencrawl/bCrawl';
  } elsif ($ver eq 'kimchicrawl') {
    do_update 'gcc', 'kimchicrawl crawl-forks/kimchicrawl/bugfix 7';
  } elsif ($ver eq 'addedcrawl') {
    do_update 'gcc', 'addedcrawl crawl-forks/addedcrawl/bugfix 7';
  } else {
    do_fail "Unknown version " . escapeHTML($ver);
  }
}

main();
