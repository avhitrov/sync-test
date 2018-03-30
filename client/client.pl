#!/usr/bin/perl

use strict;
use warnings "all";
use FindBin;

#use IO::Async::Stream;
#use IO::Async::Loop;
use IO::Socket::INET;
use IO::Select;

`mkdir -p $FindBin::Bin/out`;
my $file = $ARGV[0] || "$FindBin::Bin/out/replica";
open my $fh, ">>", $file;

#my $s = IO::Select->new();
#my $loop = IO::Async::Loop->new;
my $filesize = (stat $fh)[7] || 0;

while ( 1 ) {
	if ( my $socket = IO::Socket::INET->new( PeerAddr => 'gs2.dat.ru', PeerPort => '9999', Proto => 'tcp', Type => SOCK_STREAM ) ) {
		print $socket "get from $filesize\n";
		my $data;
		while ( my $bytes = sysread( $socket, $data, 1024 ) ) {
			syswrite $fh, $data, $bytes;
			print $data;
		}
	} else {
		print "Can't connect to socket\n";
		sleep 5;
	}
}



#$loop->connect(
#	host	=> "gs2.dat.ru",
#	service	=> 9999,
#	socktype	=> 'stream',
#
#	on_connected => sub {
#		my $socket = shift;
#		$socket->send( "get from $filesize\n" );
#		print "\n\nAnother one loop: get from $filesize\n\n";
#	},

#	on_stream => sub {
#		my $stream = shift;
#
#		$stream->configure(
#			on_read => sub {
#				my ( $self, $buffref, $eof ) = @_;
#
#				print $fh $$buffref;
#				print $$buffref;
#				return 0;
#			}
#		);
#		$loop->add( $stream );
#	},
#
#	on_resolve_error => sub { die "Cannot resolve - $_[-1]\n"; },
#	on_connect_error => sub { die "Cannot connect - $_[0] failed $_[-1]\n"; },
# );

#$loop->run;