use strict;
use warnings;
package Mojolicious::Plugin::Pubsub;
#ABSTRACT: Pubsub plugin for Mojolicious

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::IOLoop;
use Mojo::JSON qw( decode_json encode_json );
use Mojo::Util qw( b64_decode b64_encode );

my $client;
my $conf;

sub register {
  my ($self, $app, $cfg) = @_;

  die "No callback specified { cb => sub { ... } }" unless exists $cfg->{cb};
  $cfg->{socket} = $app->moniker . '.pubsub' unless exists $cfg->{socket};
  $conf = $cfg;

  my $sub = Mojo::IOLoop->subprocess(
    sub {
      my $loop = Mojo::IOLoop->singleton;
      $loop->reset;

      my @streams;

      my $server = $loop->server(
        {path => $conf->{socket}} => sub {
          my ($loop, $stream, $id) = @_;
          push @streams, $stream;

          my $msg;
          $stream->on(
            read => sub {
              my ($stream, $bytes) = @_;
              $msg .= $bytes;

              while (length $msg) {
                if ($msg =~ s/^(.+\n)//) {
                  my $line = $1;
                  foreach my $str (@streams) { $str->write($line); }
                } else {
                  return;
                }
              }

            }
          );

          $stream->on(
            close => sub {
              @streams = grep $_ ne $_[0], @streams;
              $loop->stop unless @streams;
            }
          );
        }
      );

      $loop->start unless $loop->is_running;
      unlink $conf->{socket};
    }
  );

  Mojo::IOLoop->singleton->next_tick(sub { _connect() });

  $app->helper(
    publish => sub {
      my $self = shift;
      my $msg = b64_encode(encode_json([@_]), "");

      _send($msg . "\n");
    }
  );

}

sub _send {
  my ($msg) = @_;

  if (not defined $client) {
    return _connect(sub { $_[0]->write($msg); });
  }

  $client->write($msg);
}

sub _connect {

  my $cb = shift;

  Mojo::IOLoop->singleton->client(
    { path => $conf->{socket} } => sub {
      my ($loop, $err, $stream) = @_;
      die sprintf "Could not connect to %s: %s", $conf->{socket}, $err if defined $err;

      if (defined $client) {
        $stream->close();
        $cb->($client) if defined $cb;

        return;
      }

      $client = $stream;

      my $msg;
      $stream->on(read => sub {
        my ($stream, $bytes) = @_;

        $msg .= $bytes;

        while (length $msg) {
          if ($msg =~ s/^(.+)\n//) {
            my $b64 = $1;
            my $args = decode_json(b64_decode($b64));
            $conf->{cb}->(@{ $args });
          }
          else {
            return
          }

        }
      });

      $cb->($stream) if defined $cb;

    }
  );
}

1;

__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Pubsub - Pubsub plugin for Mojolicious

=head1 SYNOPSIS

  # Mojolicious
  my $pubsub = $app->plugin('Pubsub', { cb => sub { print "Message: $_[0]\n"; }, socket => 'myapp.pubsub', });
  $app->publish("message");
  
  # Mojolicious::Lite
  my $pubsub = plugin Pubsub => { cb => sub { print "Message: $_[0]\n"; }, socket => 'myapp.pubsub', };
  app->publish("message");

=head1 DESCRIPTION

Easy way to add pubsub to your Mojolicious apps; it hooks into the L<Mojo::IOLoop> to send and receive messages asynchronously.

=head1 OPTIONS

=head2 cb

Takes a callback C<CODE> reference. Specifying a callback in C<cb> is required, as that's the only recourse you have of getting a published message.

=head2 socket

A path to a C<UNIX> socket used to communicate between the publishers. By default this will be C<< $app->moniker . '.pubsub' >>.

=head1 HELPERS

=head2 publish

  $c->publish("message");

Publishes a message that the callback will receive.

=head1 METHODS

=head2 register

  my $pubsub = $plugin->register(Mojolicious->new, { cb => sub { ... }, socket => $path });

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojo::Redis2>.
