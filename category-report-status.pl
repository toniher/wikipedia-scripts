#!/usr/bin/env perl -w
 
use MediaWiki::API;
use LWP::Simple qw(get);
use JSON qw(from_json);
use URI::Escape;
use Data::Dumper;
use utf8; 

use 5.010;
binmode STDOUT, ":utf8";

# GetOpt

# Category
# Language

my $mw = MediaWiki::API->new();
# URL
$mw->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';

# get a list of articles in category
my $articles = $mw->list ( {
action => 'query',
list => 'categorymembers',
cmtitle => 'Category:Perl',
cmlimit => 'max' } )
|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

# and print the article titles
foreach (@{$articles}) {
	print "$_->{title}\n";
}

