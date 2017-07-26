#!usr/bin/env perl


my $file = shift;
my $dirout = shift // "sep" ;
my $map = shift // 4;

# Directory with Wikidata pieces
if ( ! defined( $file ) ) {
	exit;
}

if ( ! -d $dirout ) {
	mkdir( $dirout );
}

my @keys = processFile( $file, $map );

foreach my $key ( @keys ) {
	
	my $fileout = $file;
	$fileout =~ s/\.csv//g;
	
	my $finkey = $key;
	$finkey =~ s/\s/_/g;
	$finkey =~ s/\'//g;
	$finkey =~ s/«//g;
	$finkey =~ s/»//g;

	if ( $finkey eq '' ) {
		$finkey = "sensetaxonomia";
	}
	
	
	open( FILEOUT, ">".$dirout."/".$fileout.".".$finkey.".csv" );
	
	my $iter = 0;
	
	open( FILE, $file );
	
	while (<FILE>) {
		
		if ( $iter == 0 ) {
			print FILEOUT $_;
		} else {
			
			my @split = split( /\t/, $_ );
			
			if ( $split[ $map ] eq $key ) {
				print FILEOUT $_;
			}
		}
		
		
		$iter++;
	}
	
	close( FILE );
	
	close( FILEOUT );
	
}

sub processFile  {
	
	my $fils = shift;
	my $map = shift;
	
	my @arr;
	
	open( FILE, $file );
	
	my $iter = 0;
	
	while (<FILE>) {
		
		if ( $iter > 0 ) {
			my @split = split( /\t/, $_ );
		
			push( @arr, $split[$map] );
		}
		
		$iter++;
		
	}
	
	close( FILE );	
	
	return uniq( @arr );
	
}



sub uniq {
	my %seen;
	return grep { !$seen{$_}++ } @_;
}
