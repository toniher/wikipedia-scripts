#!/usr/bin/env perl

use 5.010;

use JSON;
use Parallel::ForkManager;
use Data::Dumper;

use utf8;
binmode(STDOUT, ":utf8");

# Directory of dumps
my $dir = shift;
my $procs = shift // 4;
my $langstr = shift // "ca,es"; #Two languages to check
my $dirout = shift // "out";

# Directory with Wikidata pieces
if ( ! defined( $dir ) ) {
	exit;
}

my @langs = split(",", $langstr);


opendir( DIR, $dir ) or die $!;

my $fork= new Parallel::ForkManager( $procs );

while ( my $file = readdir(DIR) ) {
	
	if ( $file=~/^\./ ) { next; }
	
	my $pid= $fork->start and next;

	my $docsfile = processJSONfile( $dir."/".$file );
	
	my %report;
	$report{"docs"} = $docsfile;

	if ( ! -d $dirout ) {
		mkdir( $dirout );
	}
	
	# Output suitable for bulk upload with CouchDB
	open(FILEOUT, ">", $dirout."/".$file.".json" ) or die "Cannow write";

	print FILEOUT JSON->new->utf8(1)->encode(\%report);
	close( FILEOUT );

	$fork->finish;
}

$fork->wait_all_children;

sub processJSONfile {
	
	my $file = shift;
	my $docs;

	# Process JSON file
	# Line by line is a JSON piece
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		
		my $entityStr = $_;
		# Remove final comma
		$entityStr=~s/\,\s*$//g;
		my $entity = JSON->new->utf8(1)->decode($entityStr);
		
		my $doc = processEntity( $entity );

		if ( $doc ) {
			push( @{$docs}, $doc );
		}

	}
	
	close( FILE );
	
	return $docs;
}

sub processEntity {
	
	my $entity = shift;

	my $label = {};
	my $title = {};

	my $id = $entity->{"id"};
	my $type = $entity->{"type"};
	
	my $object = {};

	my $detail = 0;

	$object->{"_id"} = $id;
	$object->{"type"} = $type;
	
	$object->{"langs"} = {};

	
	foreach my $lang (@langs) {
	
		if ( defined( $entity->{"labels"} ) ) {
	
			if ( defined( $entity->{"labels"}->{$lang} ) ) {
				$label->{$lang} = $entity->{"labels"}->{$lang}->{"value"};
			}
			
		}
	
		if ( defined( $entity->{"sitelinks"} ) ) {
	
			if ( defined( $entity->{"sitelinks"}->{$lang."wiki"} ) ) {
				$title->{$lang} = $entity->{"sitelinks"}->{$lang."wiki"}->{"title"};
			}
			
		}
	
		# Let's handle property in a different way
		if ( $type eq 'property' ) {
			$object->{"langs"}->{$lang} = {};
			
			if ( defined( $label->{$lang} ) ) {
				$object->{"langs"}->{$lang}->{"label"} = $label->{$lang};
			} else {
				$object->{"langs"}->{$lang}->{"label"} = undef;
			}

		} else {
		
			if ( $title->{$lang} ) {
				if ( $label->{$lang} ne $title->{$lang} ) {
	
					$object->{"langs"}->{$lang} = {};
					$object->{"langs"}->{$lang}->{"label"} = $label->{$lang};
					$object->{"langs"}->{$lang}->{"title"} = $title->{$lang};
					
					# Handle discrepancy cases
					# Capitalization
					if ( lc( $label->{$lang} ) eq lc( $title->{$lang} ) ) {
						$detail = 1;
					} else {
						my $modifTitle = $title->{$lang};
						# Remove last parenthesis
						$modifTitle=~s/\s*\(.*?\)\s*$//g;
						
						if ( $label->{$lang} eq $modifTitle ) {
							$detail  = 2;
						} else {
							if ( lc( $label->{$lang} ) eq lc( $modifTitle ) ) {
								$detail = 3;
							}
						}
					}
					
					# Null label
					if ( !$label->{$lang} ) {
						$detail = -1;
					}
		
					$object->{"langs"}->{$lang}->{"detail"} = $detail;
		
				}
				
			}
		
		}
		
	}
	
	my @listkeys = keys %{$object->{"langs"}};

	if ( scalar @listkeys > 0 ) {
		return $object;
	}
	
	
	return 0;
}

