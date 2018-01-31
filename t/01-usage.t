use Mojo::IOLoop;
use Mojo::IOLoop::Server;
use Mojolicious::Lite;
use Test::More;

my $port = Mojo::IOLoop::Server->generate_port();

my $msg;
plugin Pubsub => { cb => sub { $msg = shift; Mojo::IOLoop->stop; } };

app->log->level('warn');
app->publish('message');
app->start('daemon', '-l', "http://127.0.0.1:$port");



is ($msg, 'message', "Pubsub works fine.");

done_testing;
