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
	$server->{'server'}{'info'}{'connect'}++;
	$server->{'server'}{'request'} = {};
	my $request = $server->{'server'}{'request'};
	while (my $cmd = <STDIN>) {
		chomp $cmd;
		if ( $cmd =~ /^get from (\d+)/i ) {
			my $offset = $1;
			$server->log(DEBUG, "Start from $offset");

			open my $fh, "<", $server->{'server'}{'file'}		or return;

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
#			print "Connections: ".($server->{'server'}{'info'}{'connect'} || 0)."\n"; 
#			print "Client sync: ".($server->{'server'}{'info'}{'sync'} || 0)."\n"; 
			print Dumper($server);
			my $socket = $server->{'server'}{'parent_sock'};
			if ( $socket ) {
				print $socket "info\n";
			}
		} elsif ( $cmd =~ /^close/i ) {
			return 0;
		}
	}
}

sub post_process_request_hook {
	my $server = shift;
	$server->{'server'}{'info'}{'connect'} = $server->{'server'}{'info'}{'connect'} > 0 ? $server->{'server'}{'info'}{'connect'} - 1 : 0;
	my $request = $server->{'server'}{'request'};
	if ( exists $request->{fh} ) {
		close $request->{fh};
	}
	if ( exists $request->{loop} ) {
		$request->{loop}->stop;
	}
	delete $server->{'server'}{'request'};
	$server->log(DEBUG, "Client connection cleared");
}

sub child_is_talking_hook {
	my ($server, $child) = @_;
	$server->log(DEBUG, "Child is talking!");
	$server->log(DEBUG, Dumper($server));
	my $data_read;
	while ( $child->recv($data_read, 256) ) {
		$server->log(DEBUG, $data_read);
	}
}

1;