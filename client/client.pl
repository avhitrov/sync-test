#!/usr/bin/perl

use strict;
use warnings "all";
use FindBin;

use IO::Async::Stream;
use IO::Async::Loop;

`mkdir -p $FindBin::Bin/out`;
my $file = $ARGV[0] || "$FindBin::Bin/out/replica";
open my $fh, ">>", $file;


my $loop = IO::Async::Loop->new;

my $filesize = (stat $fh)[7] || 0;

$loop->connect(
	host	=> "gs2.dat.ru",
	service	=> 9999,
	socktype	=> 'stream',

	on_stream => sub {
		my ( $stream ) = @_;

		$stream->configure(
			on_read => sub {
				my ( $self, $buffref, $eof ) = @_;

				print $fh $$buffref;
				print $$buffref;
				return 0;
			}
		);

		$stream->write( "get from $filesize\n" );

		$loop->add( $stream );
	},

	on_resolve_error => sub { die "Cannot resolve - $_[-1]\n"; },
	on_connect_error => sub { die "Cannot connect - $_[0] failed $_[-1]\n"; },
 );

 $loop->run;