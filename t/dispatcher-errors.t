use v5.36;
use Test::More;
use Catalyst::Plugin::JSONRPC::Server::Dispatcher;
use Catalyst::Plugin::JSONRPC::Server::Error;

my $d = Catalyst::Plugin::JSONRPC::Server::Dispatcher->new;
$d->register( ok_method => sub ($p) { 'fine' } );
$d->register( boom      => sub ($p) { die "kaboom at secret place\n" } );
$d->register( bad_param => sub ($p) {
    Catalyst::Plugin::JSONRPC::Server::Error->throw(
        code => -32602, message => 'Invalid params' );
} );

# -32700 parse error (id is null)
is_deeply( $d->dispatch('this is not json'),
    { jsonrpc => '2.0', error => { code => -32700, message => 'Parse error' }, id => undef },
    'parse error' );

# -32600 not a JSON object
is_deeply( $d->dispatch('"a bare string"'),
    { jsonrpc => '2.0', error => { code => -32600, message => 'Invalid Request' }, id => undef },
    'non-object request is invalid' );

# -32600 wrong jsonrpc version (keeps the id)
is_deeply( $d->dispatch('{"jsonrpc":"1.0","method":"ok_method","id":9}'),
    { jsonrpc => '2.0', error => { code => -32600, message => 'Invalid Request' }, id => 9 },
    'bad jsonrpc version is invalid' );

# -32600 bad params type
is_deeply( $d->dispatch('{"jsonrpc":"2.0","method":"ok_method","params":"x","id":9}'),
    { jsonrpc => '2.0', error => { code => -32600, message => 'Invalid Request' }, id => 9 },
    'scalar params is invalid' );

# -32601 method not found
is_deeply( $d->dispatch('{"jsonrpc":"2.0","method":"nope","id":3}'),
    { jsonrpc => '2.0', error => { code => -32601, message => 'Method not found' }, id => 3 },
    'method not found' );

# handler dies plainly -> -32603, original message NOT leaked
is_deeply( $d->dispatch('{"jsonrpc":"2.0","method":"boom","id":4}'),
    { jsonrpc => '2.0', error => { code => -32603, message => 'Internal error' }, id => 4 },
    'plain die maps to internal error without leaking text' );

# handler throws a structured Error -> its code/message
is_deeply( $d->dispatch('{"jsonrpc":"2.0","method":"bad_param","id":5}'),
    { jsonrpc => '2.0', error => { code => -32602, message => 'Invalid params' }, id => 5 },
    'structured Error maps to its code' );

done_testing;
