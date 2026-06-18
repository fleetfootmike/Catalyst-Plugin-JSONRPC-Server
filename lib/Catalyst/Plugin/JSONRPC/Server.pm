package Catalyst::Plugin::JSONRPC::Server;
use v5.36;

our $VERSION = '0.001';

=head1 NAME

Catalyst::Plugin::JSONRPC::Server - Generic JSON-RPC 2.0 server plugin for Catalyst

=head1 DESCRIPTION

Adds JSON-RPC 2.0 request dispatch to a Catalyst application. The protocol
engine lives in L<Catalyst::Plugin::JSONRPC::Server::Dispatcher>; this module is
the thin Catalyst seam (added in a later task).

=cut

1;
