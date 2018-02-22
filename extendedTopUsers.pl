#!/usr/bin/env perl

use warnings;
use MediaWiki::API;
use LWP::Simple qw(get);
use JSON qw(from_json);
use URI::Escape;
use Data::Dumper;
use Config::JSON;
use Text::Trim;
use utf8; 


use 5.010;
binmode STDOUT, ":utf8";

my $configfile = shift // "extendTopUsers.json";
my $listwiki = shift // "wikidatawiki,commonswiki,mediawikiwiki,metawiki";

my @listwiki = split( /,/, $listwiki );
@listwiki = map { trim( $_ ) } @listwiki;

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

my $mw = $mwcontainer->{"target"}->{$targetlang};

# Get top users
# https://ca.wikipedia.org/wiki/Viquip%C3%A8dia:Llista_de_viquipedistes_per_nombre_d%27edicions
my $page = $mw->get_page( { title => "Viquipèdia:Llista_de_viquipedistes_per_nombre_d'edicions" } );
# print page contents
my $text = $page->{'*'};

my @lines = split( /\n/, $text );
my $ntext = "";

foreach my $line (@lines) {
	
	if ( $line=~/User\:/ ) {
		my @fields = split( /\|\|/, $line );
		#print $fields[1];
		
		my ($user)=$fields[1]=~/User:(.*)?\|/g;
		
		print $user, "\n";
		my %map = &get_stats_user( $user );
		
		my @textarr;
		push( @textarr, $fields[0] );
		push( @textarr, $fields[1] );
		push( @textarr, $fields[2] );

		
		foreach my $wiki ( @listwiki ) {
			if ( defined( $map{$wiki} ) ) {
				$user =~ s/\s/_/g;
				my $url = $map{$wiki}[0]."/wiki/Special:Contributions/".$user;

				my $editcount = $map{$wiki}[1];
				
				my $part = "[$url $editcount]";
				
				push( @textarr, $part );
			} else {
				push( @textarr, "" );	
			}
		}
		
		push( @textarr, $fields[3] );
	
		$ntext = $ntext . join( " || ", @textarr )."\n";
		
		sleep( $sleep );

	} else {
		$ntext = $ntext . $line."\n";
	}
}

&edit( $mw, "Usuari:Toniher/Llista de viquipedistes per nombre d'edicions", $ntext, "Catabot a l'actac" );

# Apply query
# https://www.mediawiki.org/w/api.php?action=query&meta=globaluserinfo&guiuser=XXX&guiprop=merged
sub get_stats_user {
	
	my $user = shift;
	my %map;
	
	my $stats_url = "https://www.mediawiki.org/w/api.php?action=query&meta=globaluserinfo&guiuser=".$user."&guiprop=merged&format=json";

	my $content = from_json(full_get($stats_url));
	
	if ( defined( $content ) ) {
		
		%map = &retrieveinfo( $content );
	}
	
	return %map;
	
}

sub retrieveinfo {
	
	my $content = shift;
	my %map;
						
	if ( defined( $content->{"query"} ) ) {
		
		if ( defined( $content->{"query"}->{"globaluserinfo"} ) ) {
	
			if ( defined( $content->{"query"}->{"globaluserinfo"}->{"merged"} ) ) {
			
				my $wikis = $content->{"query"}->{"globaluserinfo"}->{"merged"};
				
				foreach my $wiki ( @{$wikis} ) {
					
					my $url = "";
					my $editcount = 0;
					my $type = 0;

					if ( $wiki->{"wiki"} ) {
						$type = $wiki->{"wiki"};
					}
					
					if ( grep( /^$type$/, @listwiki ) ) {

						
						if ( $wiki->{"url"} ) {
							$url = $wiki->{"url"};
						}
						if ( $wiki->{"editcount"} ) {
							$editcount = $wiki->{"editcount"};
						}
						
						$map{$type} = [ $url, $editcount ];

						
					}
				}
				
				
			}
	
	
		}
	
	}
	
	return %map;
}

sub full_get {

	my $url = shift;
	my $retry = shift // 0;
	
	if ( $retry > 5 ) {
		die "too many retries";
	}
	
	$content = get($url);
	$retry++;
	full_get($url, $retry) unless defined $content;
	
	return $content;
	
}



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

