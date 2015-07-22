#!/usr/bin/env perl

use 5.016;
use warnings;
use strict;

use IO::Prompter;
use HTTP::Tiny;
use URI::Escape;
use JSON::XS qw(decode_json);

my $ua = HTTP::Tiny->new;

my @queue;
my @search;

while (my $line = prompt("BOOM> ")) {
    my ($cmd, @args) = split '\s+', $line;

    ({
        search   => \&search,
        list     => \&list,
        add      => \&add,
        del      => \&del,
        up       => \&up,
        down     => \&down,
    }->{$cmd} // sub { say "wat?" })->(@args);
}

sub _valid_queue {
    my ($n) = @_;
    unless ($n >= 1) {
        say "weird song number";
        return;
    }
    if ($n > $#queue+1) {
        say "song $n not in queue";
        return;
    }
    return 1;
}

sub _sort_queue {
    @queue = sort { $b->{score} <=> $a->{score} } @queue;
}

sub _song_pretty {
    my ($song) = @_;
    return "$song->{name} by $song->{artist} from $song->{album}";
}

sub search {
    my (@args) = @_;
    my $res = $ua->get("https://api.spotify.com/v1/search?type=album,artist,playlist,track&q=" . join('+', map { uri_escape($_) } @args));
    unless ($res->{success}) {
        say "search error: $res->{status} $res->{reason}";
        return;
    }
    my $data = decode_json($res->{content});
    @search = map { {
        name   => $_->{name},
        artist => $_->{artists}->[0]->{name} // '',
        album  => $_->{album}->{name} // '',
        href   => $_->{href},
        score  => 0,
    } } @{$data->{tracks}->{items}};

    for (1..$#search+1) {
        say "$_: "._song_pretty($search[$_-1]);
    }
}

sub list {
    my (@args) = @_;
    for (1..$#queue+1) {
        my $song = $queue[$_-1];
        say "$_: [$song->{score}] "._song_pretty($song);
    }
}

sub add {
    my ($n) = @_;
    unless ($n >= 1) {
        say "weird song number";
        return;
    }
    my $song = $search[$n-1];
    unless ($song) {
        say "no search result $n";
        return;
    }
    if (grep { $_->{href} eq $song->{href} } @queue) {
        say "search result $n already in playlist";
        return;
    }
    push @queue, $song;
    _sort_queue();
}

sub del {
    my ($n) = @_;
    return unless _valid_queue($n);
    splice @queue, $n-1, 1;
    _sort_queue();
}

sub up {
    my ($n) = @_;
    return unless _valid_queue($n);
    $queue[$n-1]->{score} += 1;
    _sort_queue();
}

sub down {
    my ($n) = @_;
    return unless _valid_queue($n);
    $queue[$n-1]->{score} -= 1;
    _sort_queue();
}
