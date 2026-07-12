package Catalyst::Plugin::JSONRPC::Server::Error;
use v5.36;
use Moo;
use namespace::clean;

our $VERSION = '0.002';

has code    => ( is => 'ro', required => 1 );
has message => ( is => 'ro', required => 1 );
has data    => ( is => 'ro' );

sub throw ( $class, %args ) {
    die $class->new(%args);
}

=head1 NAME

Catalyst::Plugin::JSONRPC::Server::Error - a structured JSON-RPC error

=head1 DESCRIPTION

A handler may throw one of these to return a specific JSON-RPC error from
L<Catalyst::Plugin::JSONRPC::Server::Dispatcher>. Attributes: C<code>
(required), C<message> (required), C<data> (optional).

=head1 METHODS

=head2 throw( code => $n, message => $str, data => $any )

Convenience constructor that C<die>s a new instance.

=cut

1;
