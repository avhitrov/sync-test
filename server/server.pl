#!/usr/bin/perl

use strict;
use warnings "all";
use FindBin;

use lib "$FindBin::Bin/lib";

use TCPServer;

our $server = TCPServer->new(conf_file => "$FindBin::Bin/etc/server.cfg"); 

$server->run();