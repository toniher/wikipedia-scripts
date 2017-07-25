#!/usr/bin/env perl

use Text::Trim;

my $file = shift;

my $json = " {\"taxonomy\": {\n";

open( FILE, $file ) || die "cannot open $file";

my @lines;

while( <FILE> ) {
	
	my (@parts) = split(/\t/, $_, 2 );
	
	push( @lines, "\t\"".trim(lc($parts[0]))."\": \"".trim($parts[1])."\"" );
	
}

close( FILE );

$json = $json.join( ",\n", @lines );

$json = $json."\n}}";

print $json;