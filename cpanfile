requires 'perl', '5.036';
requires 'Moo';
requires 'JSON::MaybeXS';
requires 'Try::Tiny';
requires 'namespace::clean';
requires 'Catalyst::Runtime', '5.90000';

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Fatal';
    requires 'HTTP::Request::Common';
};
