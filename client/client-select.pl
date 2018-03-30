#!/usr/bin/perl

use strict;
use warnings "all";
use FindBin;

use IO::Select;
use IO::Socket::INET;

`mkdir -p $FindBin::Bin/out`;

my $file = $ARGV[0] || "$FindBin::Bin/out/replica";
my $host = 'localhost';
my $port = 9999;
my $buffsize = 1024;

open my $fh, ">>", $file;
my $filesize = (stat $fh)[7] || 0;

my $sel = IO::Select->new;
while ( 1 ) {
	my $tick = time + 5;
	my $socket = IO::Socket::INET->new( PeerAddr => $host, PeerPort => $port, Proto => 'tcp', Type => SOCK_STREAM, Timeout => 10 );
	if ( $socket && $socket->connected ) {
		print "Connected\n";
		$socket->send("get from $filesize\n");
		$sel->add( $socket );
	}
	while ( my @ready = $sel->can_read ) {
		foreach my $sock (@ready) {
			my $data;
			my $res = sysread($socket, $data, $buffsize, 0);
			if ( defined $res && $res ) {
					print $data;
					syswrite $fh, $data;
			} elsif ( !defined $res || !defined $data ) {
				$sel->remove( $sock );
			} elsif ( time > $tick ) {
				my $check = $socket->send("");
				if ( $check ) {
					$tick = time;
				} else {
					$sel->remove( $sock );
				}
			}
		}
	}
	$filesize = (stat $fh)[7];
	close($socket)	if $socket;
	print "Trying to connect\n";
	sleep 5;
}
