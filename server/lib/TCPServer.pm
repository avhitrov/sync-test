package TCPServer;

use strict;
use warnings;
use base qw(Net::Server::PreFork);

sub process_request {
	my $self = shift;
	while (<STDIN>) {
		print "Hello!\n";
	}
}

1;