package Catalyst::Plugin::JSONRPC::Server;
use v5.36;
use Catalyst::Plugin::JSONRPC::Server::Dispatcher;

our $VERSION = '0.001';

=encoding utf8

=head1 NAME

Catalyst::Plugin::JSONRPC::Server - Generic JSON-RPC 2.0 server plugin for Catalyst

=head1 SYNOPSIS

    package MyApp;
    use Catalyst qw/+Catalyst::Plugin::JSONRPC::Server/;
    __PACKAGE__->setup;

    sub rpc :Path('/rpc') :Args(0) {
        my ( $self, $c ) = @_;
        $c->jsonrpc_register( add => sub ($params) { $params->{a} + $params->{b} } );
        $c->jsonrpc_dispatch;
    }

=head1 DESCRIPTION

Adds JSON-RPC 2.0 request dispatch to a Catalyst application. The protocol
engine lives in L<Catalyst::Plugin::JSONRPC::Server::Dispatcher>; this module is
the thin Catalyst seam: it adds C<jsonrpc_register> and C<jsonrpc_dispatch> to
the context.

=cut

my %DISPATCHER;    # application class => Dispatcher (one per app)

sub _jsonrpc_dispatcher ( $c ) {
    my $app = ref($c) || $c;
    return $DISPATCHER{$app}
        //= Catalyst::Plugin::JSONRPC::Server::Dispatcher->new;
}

sub jsonrpc_register ( $c, $method, $code ) {
    $c->_jsonrpc_dispatcher->register( $method, $code );
    return $c;
}

sub jsonrpc_dispatch ( $c, $body = undef ) {
    $body //= $c->_jsonrpc_read_body;
    my $dispatcher = $c->_jsonrpc_dispatcher;
    my $data       = $dispatcher->dispatch($body);
    my $res        = $c->response;

    if ( !defined $data ) {
        $res->status(204);
        $res->body(q{});
        return undef;
    }

    $res->status(200);
    $res->content_type('application/json');
    $res->body( $dispatcher->encode($data) );
    return $data;
}

# Read the raw (undecoded) request body. Catalyst buffers it; $c->request->body
# is a (usually seekable) filehandle for content types it does not parse (e.g.
# application/json). Returns '' when there is no body. We use the builtin
# binmode/seek (not method calls) so this works on both blessed IO objects and
# plain glob filehandles; binmode guarantees raw bytes, which is what the
# Dispatcher's utf8 JSON codec expects.
sub _jsonrpc_read_body ( $c ) {
    my $body = $c->request->body;
    return q{} unless defined $body;
    return $body unless ref $body;          # some configs hand back a string
    binmode $body;                          # raw bytes (codec does the utf8 decode)
    seek $body, 0, 0;                        # rewind (Catalyst may have read it)
    local $/;
    my $content = <$body>;
    return defined $content ? $content : q{};
}

=head1 METHODS

=head2 jsonrpc_register( $method => $coderef )

Register a handler for a JSON-RPC method name. The handler is invoked as
C<< $coderef->($params) >>, where C<$params> is the request's C<params>
(an arrayref, hashref, or undef). Return the result; to signal a JSON-RPC
error, throw a L<Catalyst::Plugin::JSONRPC::Server::Error> (or C<die> with a
C<< { code, message, data } >> hashref). A plain C<die> becomes a C<-32603>
internal error whose text is not leaked. Returns C<$c> (chainable).

=head2 jsonrpc_dispatch( $body = undef )

Dispatch a JSON-RPC 2.0 request. Pass the raw JSON body, or omit it to have the
plugin read the raw request body from C<< $c->request->body >>. Writes the HTTP
response — 200 with the JSON envelope for a result or error, or 204 with an
empty body when there is nothing to send (a notification) — and returns the
response data (hashref or arrayref) or C<undef>.

=cut

1;
