#!/usr/bin/env perl -w
 
use MediaWiki::API;
use LWP::Simple qw(get);
use JSON qw(from_json);
use URI::Escape;
use Data::Dumper;
use Config::JSON;
use utf8; 


use 5.010;
binmode STDOUT, ":utf8";

my $configfile = shift // "extendTopUsers.json";
my $config = Config::JSON->new($configfile);

my $targetlang = $config->get("targetlang") // "ca";
my $sleep = $config->get("sleep") // 5;

# Container for playing with Wikipedias
my $mwcontainer;

# Then target
$mwcontainer->{"target"}->{$targetlang} = MediaWiki::API->new();
$mwcontainer->{"target"}->{$targetlang}->{config}->{api_url} = 'https://'.$targetlang.'.wikipedia.org/w/api.php';

# Username and password.
my $user = $config->get("mw/username") // "";
my $pass = $config->get("mw/password") // "";
my $host = $config->get("mw/host") // "";
my $protocol = $config->get("mw/protocol") // "";
my $path = $config->get("mw/path") // "";

$mwcontainer->{"target"}->{$targetlang}->login( {lgname => $user, lgpassword => $pass } ) || die $mwcontainer->{"target"}->{$targetlang}->{error}->{code} . ': ' . $mwcontainer->{"target"}->{$targetlang}->{error}->{details};

# Get top users
# https://ca.wikipedia.org/wiki/Viquip%C3%A8dia:Llista_de_viquipedistes_per_nombre_d%27edicions

# Apply query
# https://www.mediawiki.org/w/api.php?action=query&meta=globaluserinfo&guiuser=XXX&guiprop=merged

sub edit {

	my $mw = shift;
	my $pagename = shift;
	my $text = shift;
	my $summary = shift;

	my $ref = $mw->get_page( { title => $pagename } );
	unless ( $ref->{missing} ) {
			my $timestamp = $ref->{timestamp};
			$mw->edit( {
			  action => 'edit',
			  title => $pagename,
			  basetimestamp => $timestamp, # to avoid edit conflicts
			  text => $text } )
			  || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};
	}

	return 1;
}

