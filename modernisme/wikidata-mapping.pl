#!/usr/bin/env perl

use 5.010;

use JSON;
use Parallel::ForkManager;
use Data::Dumper;

use utf8;
binmode(STDOUT, ":utf8");

# Directory of dumps
my $dir = shift;
my $conffile = shift // "conf.json";
my $fileout = shift // "filter.csv";
my $procs = shift // 4;

my $conf = processConfFile( $conffile );

# Directory with Wikidata pieces
if ( ! defined( $dir ) ) {
	exit;
}

if ( ! -d $dirout ) {
	mkdir( $dirout );
}

opendir( DIR, $dir ) or die $!;

my $fork= new Parallel::ForkManager( $procs );

open($fhout, ">:utf8", $fileout ) or die "Cannow write";

my @line = ();

foreach my $val ( @{$conf->{"order"}} ) {
	my $label = $val;
	if ( defined( $conf->{"props"}->{$val} ) ) {
		$label = $conf->{"props"}->{$val};
	}
	push( @line, $label );
}

print $fhout join("\t", @line), "\n";

while ( my $file = readdir(DIR) ) {
	
	if ( $file=~/^\./ ) { next; }
	
	my $pid= $fork->start and next;


	my $content = &processJSONfile( $dir."/".$file );
	
	if ( $content ne '' ) {
		print $fhout $content;
	}
	
	$fork->finish;
}


close( $fhout );


$fork->wait_all_children;

sub processJSONfile {
	
	my $file = shift;
	my $text = "";

	# Process JSON file
	# Line by line is a JSON piece
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		
		my $entityStr = $_;
		my $pre = $_;
	
		# Remove final comma
		$entityStr=~s/\,\s*$//g;
		my $entity = JSON->new->utf8(1)->decode($entityStr);
		
		my $doc;
		

		$text.= processEntity( $entity );
		
	}                             
	
	close( FILE );
	
	return $text;
}


sub processEntity {
	
	my $entity = shift;
    
	my $text = "";
	
	my %store;
	
	push( @{$store{"id"}}, $entity->{"id"} );
	
	$store{"labelCa"} = ( );
	$store{"descCa"} = ( );
	$store{"labelEn"} = ( );
	$store{"descEn"} = ( );
	
	if ( defined( $entity->{"labels"} ) ) {
		
		if ( defined( $entity->{"labels"}->{"ca"} ) ) {
			if ( defined( $entity->{"labels"}->{"ca"}->{"value"} ) ) {
				push( @{$store{"labelCa"}}, $entity->{"labels"}->{"ca"}->{"value"} );
			}
		}

		if ( defined( $entity->{"labels"}->{"en"} ) ) {
			if ( defined( $entity->{"labels"}->{"en"}->{"value"} ) ) {
				push( @{$store{"labelEn"}}, $entity->{"labels"}->{"en"}->{"value"} );
			}
		}
	}
	
	if ( defined( $entity->{"descriptions"} ) ) {
		
		if ( defined( $entity->{"descriptions"}->{"ca"} ) ) {
			if ( defined( $entity->{"descriptions"}->{"ca"}->{"value"} ) ) {
				push( @{$store{"descCa"}}, $entity->{"descriptions"}->{"ca"}->{"value"} );
			}
		}

		if ( defined( $entity->{"descriptions"}->{"en"} ) ) {
			if ( defined( $entity->{"descriptions"}->{"en"}->{"value"} ) ) {
				push( @{$store{"descEn"}}, $entity->{"descriptions"}->{"en"}->{"value"} );
			}
		}
	}
	
	if ( defined( $conf->{"props"} ) ) {
				
		foreach my $prop ( keys %{ $conf->{"props"} } ) {

			if ( ! defined( $store{$prop} ) ) {
				$store{$prop} = ();
			}
	
			if ( defined( $entity->{"claims"} ) ) {
				
				$claims = $entity->{"claims"};
				
				# Exists pro
				if ( defined( $claims->{$prop} ) ) {
										
					my $snaks = $claims->{$prop};
				

					foreach my $propAss (  @{$snaks} ) {
						my $mainsnak = $propAss->{"mainsnak"};
						
						if ( defined( $mainsnak->{"snaktype"} ) ) {
							
							if ( $mainsnak->{"snaktype"} eq 'value' ) {
								
								if ( defined( $mainsnak->{"datavalue"} ) ) {
								
									my $datavalue = $mainsnak->{"datavalue"};
									
									my $value = processQvalue( $datavalue );
									
									if ( $value ) {
										
										push( @{$store{$prop} }, $value );
										
									}
									
								}
							}
						}
					}
					
				}
				
			}
			
		}
		
	}

	
	foreach my $val ( @{$conf->{"order"}} ) {
		push( @line, join(", ", @{$store{$val}} ) );
	}
	
	return join( "\t", @line )."\n" ;
	
}

sub processConfFile {
	
	my $file = shift;
	
	my $jsonStr = "";
	
	open ( FILE, "<", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		$jsonStr.= $_;
	}
	
	close( FILE );

	
	my $confEntity = JSON->new->utf8(1)->decode($jsonStr);

	return $confEntity;
	
}

sub processQvalue {
	
	my $datavalue = shift;
	my $value = 0;
	
	if ( defined( $datavalue->{"value"} ) ) {
		
		if ( defined( $datavalue->{"value"}->{"entity-type"} ) ) {
		
			if ( $datavalue->{"value"}->{"entity-type"} eq 'item' ) {
				$value =  $datavalue->{"value"}->{"id"};
			}
		
		}
	}
	
	return $value;
	
}

