#!/usr/bin/perl

use strict;
use warnings "all";
use FindBin;

use IO::Async::Stream;
use IO::Async::Loop;

`mkdir -p $FindBin::Bin/out`;
my $file = $ARGV[0] || "$FindBin::Bin/out/replica";
my $host = "localhost";
my $port = 9999;

open my $fh, ">>", $file;

my $loop = IO::Async::Loop->new;

while ( 1 ) {
	my $filesize = (stat $fh)[7] || 0;

	$loop->connect(
		host	=> $host,
		service	=> $port,
		socktype	=> 'stream',

		on_stream => sub {
			my ( $stream ) = @_;

			$stream->configure(
				on_read => sub {
					my ( $self, $buffref, $eof ) = @_;

					if ( defined $$buffref ) {
						syswrite $fh, $$buffref;
						print $$buffref;
						$$buffref = undef;
					} else {
						print "Connection lost\n";
						$loop->stop;
						$loop->remove( $self );
					}
					return 0;
				}
			);

			print "Connected\n";
			$stream->write( "get from $filesize\n" );

			$loop->add( $stream );
		},

		on_resolve_error => sub { print "Cannot resolve - $_[-1]\n"; $loop->stop; },
		on_connect_error => sub { print "Cannot connect - $_[0] failed $_[-1]\n"; $loop->stop; },
	);

	$loop->run;
	print "Trying to connect\n";
	sleep 5
}

