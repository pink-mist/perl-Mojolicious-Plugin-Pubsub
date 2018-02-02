#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

use Mojolicious::Lite;

my @messages;

plugin Pubsub => { cb => sub { push @messages, shift; } };

post '/index' => sub { my $c = shift; $c->publish($c->param('message')); $c->redirect_to('/'); };

get '/' => sub { my $c = shift; $c->render('index', messages => \@messages); };

app->start;

__DATA__

@@ index.html.ep
% use Mojo::Util 'xml_escape';
<!doctype html>
<html>
<head>
  <title>Pubsub demo</title>
</head>
<body>
  <div class="messages"><%== join '<br>', map xml_escape($_), @{ stash('messages') } %></div>
  %= form_for index => begin
    %= text_field 'message', autofocus => undef
    %= submit_button 'Send'
  %= end
</body>
</html>
