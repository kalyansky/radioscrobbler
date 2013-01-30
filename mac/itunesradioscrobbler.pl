#!/usr/bin/perl

use strict;
use Modern::Perl;
use Mac::AppleScript::Glue;
use Net::LastFM::Submission;


my $auth = get_credentials() or die "Last.fm credentials not found";
my $skipArtists = {
	'mullygan' => 1 
};


my $last_song = '';
my $ua;

$| = 1;
while (1) {
	my $song = get_song();
	if ($song && !$skipArtists->{ $song->{artist} } && $last_song ne $song->{raw}) {
		if (!$ua) {
			$ua = Net::LastFM::Submission->new( $auth );
			$ua->handshake();
		}

		print "Submitting " . $song->{raw} . "\n";
		$last_song = $song->{raw};
		$ua->submit($song);
	}

	print "Sleeping 1 minute\n";
	sleep(60);
}




sub get_song {
	my $itunes = Mac::AppleScript::Glue::Application->new('iTunes');
	my $track = $itunes->current_stream_title;
	my @t = split /\s+-\s+/, $track;

	my $artist = shift @t;
	my $song = join ' - ', @t;

	return {
		'raw' => $track,
		'artist' => $artist,
		'title' => $song
	}
}



# Get last.fm login credentials
# @return hash or undef
sub get_credentials {
	my $cred = `security 2>&1 find-generic-password -g -s "last.fm"`;
	my $data = parse_cred($cred);
	return unless $data && $data->{password} && $data->{acct};
	return {
		'user' => $data->{acct},
		'password' => $data->{password}
	}
}



# Remove leading and trailing quotes
# @return string
sub unquote {
	my $str = shift;
	$str =~ s/^\s*(.*)\s*$/$1/;
	$str =~ s/^"(.*)"$/$1/;
	return $str;
}


# Parse security output
# @return hash
sub parse_cred {
	my $str = shift;

	my $lines = [];
	foreach (split /\n/, $str) {
		if (m/^\s/) {
			next unless (@$lines);
			$lines->[ scalar @$lines - 1 ] .= "\n" . $_;
		} else {
			push @$lines, $_;
		}
	}

	my $data = { map {
		s/^(.*):\s*//;
		my $key = $1;

		$key => unquote($_)
	} @$lines };

	if ($data->{attributes}) {
		@$lines = split /\n/, $data->{attributes};
		map {
			my ($key, $value) = split /\s*\<[\w\d]+\>=\s*/;
			$data->{ unquote($key) } = $value eq '<NULL>' ? undef : unquote($value);
		} @$lines;
	}

	return $data;
}