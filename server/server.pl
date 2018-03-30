#!/usr/bin/perl

use strict;
use warnings "all";
use FindBin;
use Data::Dumper;

use lib "$FindBin::Bin/lib";

use TCPServer;
my $file = '/home/medobo/logs/nginx.access_log';

our $server = TCPServer->new(conf_file => "$FindBin::Bin/etc/server.cfg");
$server->{'server'}{'file'} = $file;

$server->run();