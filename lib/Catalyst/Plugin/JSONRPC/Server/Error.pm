package Catalyst::Plugin::JSONRPC::Server::Error;
use v5.36;
use Moo;
use namespace::clean;

our $VERSION = '0.001';

has code    => ( is => 'ro', required => 1 );
has message => ( is => 'ro', required => 1 );
has data    => ( is => 'ro' );

sub throw ( $class, %args ) {
    die $class->new(%args);
}

1;
