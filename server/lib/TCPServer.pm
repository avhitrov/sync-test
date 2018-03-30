package TCPServer;

use strict;
use warnings;
use base qw(Net::Server::PreFork);
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use IO::Async::FileStream;
use IO::Async::Loop;
use Data::Dumper;

use constant DEBUG => 4;

sub process_request {
	my $server = shift;
	my $parent = $server->{'server'}{'parent_sock'};
	if ( $parent ) {
		print $parent "connected\n";
	}
	my $request = $server->{'server'}{'request'};
	while (my $cmd = <STDIN>) {
		chomp $cmd;
		if ( $cmd =~ /^get from (\d+)/i ) {
			my $offset = $1;
			$server->log(DEBUG, "Start from $offset");

			my $fh;
			unless ( open $fh, "<", $server->{'server'}{'file'} ) {
				$server->log(0, "Can't open filename ".$server->{'server'}{'file'}.". Error: ".$!); return;
			}
			if ( $parent ) {
				print $parent "syncstart\n";
			}

			$request->{fh} = $fh;
			my $loop = IO::Async::Loop->new(
				on_finish => sub {
					$server->{'server'}{'info'}{'sync'} = $server->{'server'}{'info'}{'sync'} > 0 ? $server->{'server'}{'info'}{'sync'} - 1 : 0;
				},
			);
			$request->{loop} = $loop;
			my $filesize = (stat $fh)[7];
			if ( $offset < $filesize ) {
				seek $fh, $offset, SEEK_SET;
				my $buffer;
				while ( read( $fh, $buffer, 8192) ) {
					print $buffer;
				}
			} elsif ( $offset > $filesize ) {
				$server->log(DEBUG, "Remote file is larger: $offset > $filesize");
			}
			my $filestream = IO::Async::FileStream->new(
				read_handle => $fh,
 
				on_initial => sub {
					my $self = shift;
					$server->{'server'}{'info'}{'sync'}++;
					$self->seek( 0, SEEK_END );
				},
 
				on_read => sub {
					my ( $self, $buffref ) = @_;
					print $$buffref;
					$$buffref = undef;
					return 0;
				},
			);
			$loop->add( $filestream );
			$loop->run;
		} elsif ( $cmd =~ /^info/i ) {
#			print Dumper($server);
			my $parent = $server->{'server'}{'parent_sock'};
			if ( $parent ) {
				print $parent "info\n";
				my $response = <$parent>;
				$server->log(DEBUG, $response);
				if ( $response ) {
					chomp $response;
					my %response = split /:/, $response;
					print "Connections: $response{'conn'}\n"; 
					print "Client sync: $response{'sync'}\n"; 
				}
			}
			return 0;
		} elsif ( $cmd =~ /^close/i ) {
			return 0;
		}
	}
}

sub post_process_request_hook {
	my $server = shift;
	my $parent = $server->{'server'}{'parent_sock'};
	my $request = $server->{'server'}{'request'};
	if ( exists $request->{fh} ) {
		if ( $parent ) {
			print $parent "syncstop\n";
		}
		close $request->{fh};
	}
	if ( exists $request->{loop} ) {
		$request->{loop}->stop;
	}
	delete $server->{'server'}{'request'};
	if ( $parent ) {
		print $parent "disconnected\n";
	}
	$server->log(DEBUG, "Client connection cleared");
}

sub child_is_talking_hook {
	my ($server, $child) = @_;
	my $data_read = <$child>;
	if ( $data_read ) {
		$server->log(DEBUG, "Child is talking!");
		$server->log(DEBUG, $data_read);
		if ( $data_read =~ /^info/ ) {
			my $info = "conn:".($server->{info}{conn}|| 0).":sync:".($server->{info}{sync} || 0)."\n";
			syswrite($child, $info);
		} elsif ( $data_read =~ /^syncstart/ ) {
			$server->{info}{sync}++;
		} elsif ( $data_read =~ /^syncstop/ ) {
			$server->{info}{sync} = $server->{info}{sync} > 0 ? $server->{info}{sync}-1 : 0 ;
		} elsif ( $data_read =~ /^connected/ ) {
			$server->{info}{conn}++;
		} elsif ( $data_read =~ /^disconnected/ ) {
			$server->{info}{conn} = $server->{info}{conn} > 0 ? $server->{info}{conn}-1 : 0 ;
		}
	}
	return 0;
}

1;