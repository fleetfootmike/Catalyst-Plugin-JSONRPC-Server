package Catalyst::Plugin::JSONRPC::Server::Dispatcher;
use v5.36;
use Moo;
use JSON::MaybeXS ();
use Try::Tiny;
use Carp qw/croak/;
use Scalar::Util qw/blessed/;
use Catalyst::Plugin::JSONRPC::Server::Error;
use namespace::clean;

our $VERSION = '0.001';

has _handlers => ( is => 'ro', default => sub { {} } );
has _json => (
    is      => 'lazy',
    builder => sub { JSON::MaybeXS->new( utf8 => 1, canonical => 1 ) },
);

sub register ( $self, $method, $code ) {
    croak "JSON-RPC method must be a non-empty string"
        unless defined $method && !ref $method && length $method;
    croak "JSON-RPC handler must be a CODE ref"
        unless ref $code eq 'CODE';
    $self->_handlers->{$method} = $code;
    return $self;
}

sub encode ( $self, $data ) {
    return $self->_json->encode($data);
}

# Returns: hashref (single), arrayref (batch), or undef (nothing to send).
sub dispatch ( $self, $json_text ) {
    my $decoded;
    my $parsed = try { $decoded = $self->_json->decode($json_text); 1 }
                 catch { 0 };
    return $self->_error( undef, -32700, 'Parse error' ) unless $parsed;

    if ( ref $decoded eq 'ARRAY' ) {
        return $self->_error( undef, -32600, 'Invalid Request' )
            unless @$decoded;
        my @out = grep { defined } map { $self->_handle_one($_) } @$decoded;
        return @out ? \@out : undef;
    }

    return $self->_handle_one($decoded);
}

# One already-decoded request element -> response hashref or undef (notification)
sub _handle_one ( $self, $req ) {
    return $self->_error( undef, -32600, 'Invalid Request' )
        unless ref $req eq 'HASH';

    my $is_note = !exists $req->{id};
    my $id      = $req->{id};    # undef for notifications; may be a JSON null

    # Envelope validation
    my $valid =
           defined $req->{jsonrpc} && $req->{jsonrpc} eq '2.0'
        && defined $req->{method}  && !ref $req->{method}
        && ( !exists $req->{params}
             || ref $req->{params} eq 'ARRAY'
             || ref $req->{params} eq 'HASH' );
    unless ($valid) {
        return undef if $is_note;
        return $self->_error( $id, -32600, 'Invalid Request' );
    }

    my $handler = $self->_handlers->{ $req->{method} };
    unless ($handler) {
        return undef if $is_note;
        return $self->_error( $id, -32601, 'Method not found' );
    }

    my ( $result, $err );
    try   { $result = $handler->( $req->{params} ) }
    catch { $err = $_ };

    if ( defined $err ) {
        return undef if $is_note;
        my ( $code, $message, $data ) = $self->_normalize_error($err);
        return $self->_error( $id, $code, $message, $data );
    }

    return undef if $is_note;
    return { jsonrpc => '2.0', result => $result, id => $id };
}

sub _error ( $self, $id, $code, $message, $data = undef ) {
    my %err = ( code => $code, message => $message );
    $err{data} = $data if defined $data;
    return { jsonrpc => '2.0', error => \%err, id => $id };
}

# Map a thrown value to (code, message, data). A plain die, or any unrecognised
# blessed object, becomes -32603 and the original text is NOT leaked to the
# client (only a typed ::Error or a { code, ... } hashref sets a specific code).
sub _normalize_error ( $self, $err ) {
    if ( blessed $err && $err->isa('Catalyst::Plugin::JSONRPC::Server::Error') ) {
        return ( $err->code, $err->message, $err->data );
    }
    if ( ref $err eq 'HASH' && defined $err->{code} ) {
        return ( $err->{code}, $err->{message} // 'Error', $err->{data} );
    }
    return ( -32603, 'Internal error', undef );
}

1;
