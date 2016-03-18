#!/usr/bin/env perl

my $dir = shift;
my $couch = shift;

$couch =~s/\@/\\@/g;

opendir( DIR, $dir ) || die "Cannot open $dir";

my (@files) = grep { $_=~/\.json/ } readdir( DIR );

closedir( DIR );

foreach my $file ( @files ) {

	system( "curl -H 'Content-Type: application/json' --data-binary @".$dir."/".$file." -X POST $couch" );	
}


