#!perl
# vim:ts=4:sw=4:expandtab
#
# Please read the following documents before working on tests:
# • https://build.i3wm.org/docs/testsuite.html
#   (or docs/testsuite)
#
# • https://build.i3wm.org/docs/lib-i3test.html
#   (alternatively: perldoc ./testcases/lib/i3test.pm)
#
# • https://build.i3wm.org/docs/ipc.html
#   (or docs/ipc)
#
# • http://onyxneon.com/books/modern_perl/modern_perl_a4.pdf
#   (unless you are already familiar with Perl)
#
# Verifies the include directive.

use File::Temp qw(tempfile);
use File::Basename qw(basename);
use i3test i3_autostart => 0;

# starts i3 with the given config, opens a window, returns its border style
sub launch_get_border {
    my ($config) = @_;

    my $pid = launch_with_config($config);

    my $i3 = i3(get_socket_path(0));
    my $tmp = fresh_workspace;

    my $window = open_window(name => 'special title');

    my @content = @{get_ws_content($tmp)};
    cmp_ok(@content, '==', 1, 'one node on this workspace now');
    my $border = $content[0]->{border};

    exit_gracefully($pid);

    return $border;
}

#####################################################################
# test thet windows get the default border
#####################################################################

my $config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1
EOT

is(launch_get_border($config), 'normal', 'normal border');

#####################################################################
# now use a variable and for_window
#####################################################################

my ($fh, $filename) = tempfile(UNLINK => 1);
print $fh <<'EOT';
set $vartest special title
for_window [title="$vartest"] border none
EOT
$fh->flush;

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include $filename
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# nested includes
################################################################################

my ($indirectfh, $indirectfilename) = tempfile(UNLINK => 1);
print $indirectfh <<EOT;
include $filename
EOT
$indirectfh->flush;

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include $indirectfilename
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# nested includes with relative paths
################################################################################

my $relative = basename($filename);
my ($indirectfh2, $indirectfilename2) = tempfile(UNLINK => 1);
print $indirectfh2 <<EOT;
include $relative
EOT
$indirectfh2->flush;

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include $indirectfilename2
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# command substitution
################################################################################

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include `echo $filename`
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# failing command substitution
################################################################################

$config = <<'EOT';
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include i3-`false`.conf

set $vartest special title
for_window [title="$vartest"] border none
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# permission denied
################################################################################

my ($permissiondeniedfh, $permissiondenied) = tempfile(UNLINK => 1);
$permissiondeniedfh->flush;
my $mode = 0055;
chmod($mode, $permissiondenied);

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include $permissiondenied
include $filename
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# dangling symlink
################################################################################

my ($danglingfh, $dangling) = tempfile(UNLINK => 1);
unlink($dangling);
symlink("/dangling", $dangling);

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include $dangling
set \$vartest special title
for_window [title="\$vartest"] border none
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# variables defined in the main file and used in the included file
################################################################################

my ($varfh, $var) = tempfile(UNLINK => 1);
print $varfh <<'EOT';
for_window [title="$vartest"] border none

EOT
$varfh->flush;

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

set \$vartest special title
include $var
EOT

is(launch_get_border($config), 'none', 'no border');

SKIP: {
    skip "not implemented";

################################################################################
# variables defined in the included file and used in the main file
################################################################################

($varfh, $var) = tempfile(UNLINK => 1);
print $varfh <<'EOT';
set $vartest special title
EOT
$varfh->flush;

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include $var
for_window [title="\$vartest"] border none
EOT

is(launch_get_border($config), 'none', 'no border');
}

################################################################################
# workspace names are loaded in the correct order (before reorder_bindings)
################################################################################

# The included config can be empty, the issue lies with calling parse_file
# multiple times.
my ($wsfh, $ws) = tempfile(UNLINK => 1);
$wsfh->flush;

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

bindsym 1 workspace 1: eggs
bindsym Mod4+Shift+1 workspace 11: tomatoes

include $var
EOT

# starts i3 with the given config, opens a window, returns its border style
sub launch_get_workspace_name {
    my ($config) = @_;

    my $pid = launch_with_config($config);

    my $i3 = i3(get_socket_path(0));
    my $name = $i3->get_workspaces->recv->[0]->{name};

    exit_gracefully($pid);

    return $name;
}

is(launch_get_workspace_name($config), '1: eggs', 'workspace name');

################################################################################
# loop prevention
################################################################################

my ($loopfh1, $loopname1) = tempfile(UNLINK => 1);
my ($loopfh2, $loopname2) = tempfile(UNLINK => 1);

print $loopfh1 <<EOT;
include $loopname2
EOT
$loopfh1->flush;

print $loopfh2 <<EOT;
include $loopname1
EOT
$loopfh2->flush;

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

# loop
include $loopname1

set \$vartest special title
for_window [title="\$vartest"] border none
EOT

is(launch_get_border($config), 'none', 'no border');

################################################################################
# Verify the GET_VERSION IPC reply contains all included files
################################################################################

$config = <<EOT;
# i3 config file (v4)
font -misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1

include $indirectfilename2
EOT

my $pid = launch_with_config($config);

my $i3 = i3(get_socket_path(0));
my $version = $i3->get_version()->recv;
my $included = $version->{included_config_file_names};

is_deeply($included, [ $indirectfilename2, $filename ], 'included config file names correct');

exit_gracefully($pid);

done_testing;
