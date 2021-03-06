#!/usr/bin/env perl

use 5.010;

use JSON;
use Parallel::ForkManager;
use Text::Trim;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Encode;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# Directory of dumps
my $dir = shift;
my $conffile = shift // "conf.json";
my $fileout = shift // "filter.csv";
my $qlist = shift // 0;
my $procs = shift // 4;

my $conf = processConfFile( $conffile );
my %qhash;

if ( $qlist ) {

	%qhash = processInFile( $qlist );

}

# Directory with Wikidata pieces
if ( ! defined( $dir ) ) {
	exit;
}

if ( ! -d $dirout ) {
	mkdir( $dirout );
}

opendir( DIR, $dir ) or die $!;

open($fhout, ">:utf8", $fileout ) or die "Cannow write";

my $filemap = $fileout;
$filemap=~s/\.csv//g;

open($fhmapout, ">:utf8", $filemap.".map.csv" ) or die "Cannow write";


my $fork= new Parallel::ForkManager( $procs );

my @head = ();

foreach my $val ( @{$conf->{"order"}} ) {
	my $label = $val;
	if ( defined( $conf->{"props"}->{$val} ) ) {
		$label = $conf->{"props"}->{$val};
	}
	push( @head, $label );
}

print $fhout join("\t", @head), "\n";

my @headmap = ();

foreach my $val ( @{$conf->{"ordermap"}} ) {
	push( @headmap, $val );
}

print $fhmapout join("\t", @headmap), "\n";

while ( my $file = readdir(DIR) ) {
	
	if ( $file=~/^\./ ) { next; }
	
	my $pid= $fork->start and next;


	my $content = &processJSONfile( $dir."/".$file );
	
	if ( $content->{"default"} ne '' ) {
		print $fhout $content->{"default"};
	}
	if ( $content->{"map"} ne '' ) {
		print $fhmapout $content->{"map"};
	}
	
	$fork->finish;
}


$fork->wait_all_children;

close( $fhout );
close( $fhmapout );

sub processJSONfile {
	
	my $file = shift;
	my $content;
	$content->{"default"} = "";
	$content->{"map"} = "";

	# Process JSON file
	# Line by line is a JSON piece
	
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		
		my $entityStr = $_;
	
		# Remove final comma
		$entityStr=~s/\,\s*$//g;
		my $entity = JSON->new->utf8(1)->decode($entityStr);		

		my %store = processEntity( $entity );

		my @linedef = ();
		my @linemap = ();
		
		foreach my $val ( @{$conf->{"order"}} ) {
			push( @linedef, join(", ", @{$store{$val}} ) );
		}
		
		foreach my $val ( @{$conf->{"ordermap"}} ) {
			
			if ( defined( $conf->{"map"}->{$val} ) ) {
			
				my @field;
				my @list = @{ $conf->{"map"}->{$val} };
				
				# print STDERR $val, "\n";
				
				foreach my $el ( @list ) {
					
					# print STDERR "\t".$el."\n";
					
					if ($#{$store{$el}} >= 0 ) {
						# print STDERR Dumper( $store{$el} )."\n";
						
						my (@values) = @{$store{$el}};
						
						if ( $val eq "Tipus d'obra" ) {
							@values = mapTaxonomy( @values );
						}
						
						if ( $val eq "Imatge" ) {
							@values = mapCommonsImage( @values );
						}
						
						push( @field, join( ", ", uniq( @values ) ) );
					}
				}
			
				
				push( @linemap, join(", ", uniq( @field ) ) );

			}
			

		}
		
		
		$content->{"default"} = $content->{"default"} . join( "\t", @linedef )."\n" ;
		$content->{"map"} = $content->{"map"} . join( "\t", @linemap )."\n" ;

	}                             
	
	close( FILE );
	
	return $content;
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
				push( @{$store{"labelCa"}}, "\"".escapeQuotes($entity->{"labels"}->{"ca"}->{"value"})."\"" );
			}
		}

		if ( defined( $entity->{"labels"}->{"en"} ) ) {
			if ( defined( $entity->{"labels"}->{"en"}->{"value"} ) ) {
				push( @{$store{"labelEn"}}, "\"".escapeQuotes($entity->{"labels"}->{"en"}->{"value"})."\"" );
			}
		}
	}
	
	if ( defined( $entity->{"descriptions"} ) ) {
		
		if ( defined( $entity->{"descriptions"}->{"ca"} ) ) {
			if ( defined( $entity->{"descriptions"}->{"ca"}->{"value"} ) ) {
				push( @{$store{"descCa"}}, "\"".escapeQuotes($entity->{"descriptions"}->{"ca"}->{"value"})."\"" );
			}
		}

		if ( defined( $entity->{"descriptions"}->{"en"} ) ) {
			if ( defined( $entity->{"descriptions"}->{"en"}->{"value"} ) ) {
				push( @{$store{"descEn"}}, "\"".escapeQuotes($entity->{"descriptions"}->{"en"}->{"value"})."\"" );
			}
		}
	}
	
	my @allqualifiers;
	my $claims = 0;
	
	if ( defined( $entity->{"claims"} ) ) {
	
		$claims = $entity->{"claims"};
		# TODO: Retrieve qualifiers and handle here as well
		@allqualifiers = getAllQualifiers( $claims );
	}
	
	if ( defined( $claims ) ) {
	
		if ( defined( $conf->{"props"} ) ) {
					
			foreach my $prop ( keys %{ $conf->{"props"} } ) {
	
				if ( ! defined( $store{$prop} ) ) {
					$store{$prop} = ();
				}
					
				# Exists pro
				if ( defined( $claims->{$prop} ) ) {
										
					my $snaks = $claims->{$prop};
				
	
					foreach my $propAss (  @{$snaks} ) {
						my $mainsnak = $propAss->{"mainsnak"};
						
						my $qualifiers = 0;
						if ( defined( $propAss->{"qualifiers"} ) ) {
							$qualifiers = $propAss->{"qualifiers"};
						}
						
						if ( defined( $mainsnak->{"snaktype"} ) ) {
							
							if ( $mainsnak->{"snaktype"} eq 'value' ) {
								
								if ( defined( $mainsnak->{"datavalue"} ) ) {
								
									my $datavalue = $mainsnak->{"datavalue"};
									
									my $value = processQvalue( $datavalue, $entity->{"id"}, $qualifiers, $conf, 0 );
									
									if ( $value ) {
										
										push( @{$store{$prop} }, $value );
										
									}
									
								}
							}
						}
					}
					
				}
				
				my @propQualifiers = getQualifiersWithProp( \@allqualifiers, $prop );
				
				foreach my $snaks ( @propQualifiers ) {
									
					foreach my $snak (  @{$snaks} ) {
	
						if ( defined( $snak->{"snaktype"} ) ) {
							
							if ( $snak->{"snaktype"} eq 'value' ) {
								
								if ( defined( $snak->{"datavalue"} ) ) {
								
									my $datavalue = $snak->{"datavalue"};
									
									my $value = processQvalue( $datavalue, $entity->{"id"}, 0, $conf, 1 );
									
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

	return %store;
	
}

sub getAllQualifiers {
	
	my $claims = shift;
	my @qualifiers;
	
	foreach my $prop ( keys %{ $claims } ) {
		
		my $snaks = $claims->{$prop};
				
		foreach my $propAss (  @{$snaks} ) {
			
			if ( defined( $propAss->{"qualifiers"} ) ) {
				push( @qualifiers, $propAss->{"qualifiers"} );
			}
		
		}
	}
	
	return @qualifiers;
}

sub getQualifiersWithProp {
	
	my $qualifiersList = shift;
	my $prop = shift;
	my @qualifiersProp;
	
	foreach my $qualifiers ( @{$qualifiersList} ) {
	
		foreach my $key ( keys %{ $qualifiers } ) {
			
	
			if ( $key eq $prop ) {
				push( @qualifiersProp, $qualifiers->{$prop} );
				
			}
			
		}
	}
	
	return @qualifiersProp;
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
    my $ref = shift;
	my $qualifiers = shift;
	my $conf = shift;
	
	my $qualcontext = shift;
	
	if ( $qualcontext ) {
		
		# Can be used for debugging, etc.
		#print STDERR Dumper( $datavalue ), "\n";
	}
	
	my $value = 0;
	
	
	if ( defined( $datavalue->{"value"} ) ) {
		
		if ( defined( $datavalue->{"value"}->{"entity-type"} ) ) {
		
			if ( $datavalue->{"value"}->{"entity-type"} eq 'item' ) {

				if ( $datavalue->{"value"}->{"id"} =~ /^Q/ ) {
			        $value = $datavalue->{"value"}->{"id"};
					if ( defined( $qhash{ $value } ) ) {
						$value = $qhash{ $value };
					}
                }
			}
		
		} else {
			if ( defined( $datavalue->{"type"} ) ) {
				
				if ( $datavalue->{"type"} eq 'string' ) {
					$value =  "\"".escapeQuotes( $datavalue->{"value"} )."\"";
				}
				
				if ( $datavalue->{"type"} eq 'globecoordinate' ) {
					
					if ( defined( $datavalue->{"value"}->{"latitude"} ) && defined( $datavalue->{"value"}->{"longitude"} ) ) {
						
						my $lat = $datavalue->{"value"}->{"latitude"};
						my $lon = $datavalue->{"value"}->{"longitude"};
						
						$value =  "\"".$lat.", ".$lon."\"";

					}
					
					
				}
				
				if ( $datavalue->{"type"} eq 'monolingualtext' ) {
					if ( defined( $datavalue->{"value"}->{"text"} ) ) {
						$value =  "\"".escapeQuotes( $datavalue->{"value"}->{"text"} )."\"";
					}
				}
				
				if ( $datavalue->{"type"} eq 'time' ) {
					if ( defined( $datavalue->{"value"}->{"time"} ) ) {
						
						my ($time) = $datavalue->{"value"}->{"time"} =~/(\d\S+)T/;
						my $precision = $datavalue->{"value"}->{"precision"};
						
						$time = processTime( $time, $precision, $qualifiers );
						
						$value =  "\"".$time."\"";
					}
				}
				
				if ( $datavalue->{"type"} eq 'quantity' ) {
					if ( defined( $datavalue->{"value"}->{"amount"} ) ) {
						
						my $amount = $datavalue->{"value"}->{"amount"};
						$amount =~s/\+\s*//g;
						
						my $unit = $datavalue->{"value"}->{"unit"};
						my ($qunit) = $unit=~/(Q\d+)/;
						
						if ( defined( $qunit ) && defined( $conf->{"unit"} ) ){
							if ( defined( $conf->{"unit"}->{$qunit} ) ) {
								
								$qunit = $conf->{"unit"}->{$qunit};
								
							}
						}
						
						$value =  "\"".$amount." $qunit\"";
					}
				}				
				
			}
			
		}
	}
	
	return $value;
	
}

sub processTime {
	
	my $time = shift;
	my $precision = shift;
	my $qualifiers = shift;
	
	if ( $precision < 11 ) {
		
		if ( $precision == 10 ) {
			my ( $yearmonth ) = $time =~ /^(\d+\-\d+)\-/;
			$time = $yearmonth;
		}
		
		if ( $precision == 9 ) {
			my ( $year ) = $time =~ /^(\d+)/;
			$time = $year;
		}
		
		if ( $precision < 9 ) {
			
			if ( $precision == 8 ) {
			
				my ( $year ) = $time =~ /^(\d+)/;
				$time = "decada ".$year."s";

				if ( $qualifiers ) {
					$time = processTimeQualifiers( $time, $qualifiers );
				}
				
				
			}
			
			if ( $precision == 7 ) {

				my ( $year ) = $time =~ /^(\d+)/;
				$year=~s/00//g;
				$time = "segle ".$year;	

				if ( $qualifiers ) {
					$time = processTimeQualifiers( $time, $qualifiers );	
				}

				
			}
			
			if ( $precision == 6 ) {

				my ( $year ) = $time =~ /^(\d)/;
				#$time = "mil·leni ".$year;
				$time = "";	

				if ( $qualifiers ) {
					$time = processTimeQualifiers( $time, $qualifiers );
				}
				
			}		

		}
	}
	
	return $time;
	
}

sub processTimeQualifiers {
	
	my $time = shift;
	my $qualifiers = shift;

	if ( $qualifiers ) {
		

		foreach my $key ( keys %{$qualifiers} ) {
	
			my $qualifier = $qualifiers->{$key};

			my $timeq;
			my $precisionq;

			foreach my $qval ( @{$qualifier} ) {

				if ( $qval->{"datatype"} ) {
					if ( $qval->{"datatype"} eq "time" ) {

						if ( $qval->{"datavalue"} ) {

							if ( $qval->{"datavalue"}->{"value"} ) {

								( $timeq ) = $qval->{"datavalue"}->{"value"}->{"time"} =~/(\d\S+)T/;
								$precisionq = $qval->{"datavalue"}->{"value"}->{"precision"};
								$timeq = processTime( $timeq, $precisionq, 0 );

							}
						}
					}
				}
			}
		
			if ( $key eq 'P1480' ) {
				
				# Get qualif time
				$time = "ca. ". $time;
				
			}
			
			if ( $key eq 'P1326' ) {
				
				# Get qualif time
				if ( $time ne '') {
					$time = $time. "; ";
				} 
				$time = $time."abans de ".$timeq;
				
			}		
			if ( $key eq 'P1319' ) {
				
				# Get qualif time
				if ( $time ne '') {
					$time = $time. "; ";
				} 
				$time = $time."després de ".$timeq;
			}
			
			if ( $key eq 'P580' ) {
				
				# Get qualif time
				if ( $time ne '') {
					$time = $time. "; ";
				} 
				$time = $time."inici ".$timeq;
			}
			
			if ( $key eq 'P582' ) {
				
				# Get qualif time
				if ( $time ne '') {
					$time = $time. "; ";
				} 
				$time = $time."final ".$timeq;
			}	
		}
	
	}
	
	#print STDERR $time, "\n";

	return $time;
}

sub processInFile {
	
	my $file = shift;
	my %qhash;
		
	open ( FILE, "<:encoding(UTF-8)", $file) || die "Cannot open $file";
	

	while ( <FILE> ) {
		
		my $val = trim( $_ );
		my (@split) = split(/\t/, $val, 2);
		
		if ( $split[1] ne '' ) {
			$qhash{$split[0]} = "«".$split[1]."»";
		}
	}
	
	close( FILE );

	
	return %qhash;
	
}

sub mapTaxonomy {
	
	my @values = shift;
	my @nvalues;
	
	foreach my $value ( @values ) {
		
		$value =~s/«//g;
		$value =~s/»//g;

		$value = lc( $value );
		
		if ( defined( $conf->{"taxonomy"}->{$value} ) ) {
			$value = "«".$conf->{"taxonomy"}->{$value}."»";
		} else {
			$value = "@".$value;	
		}
		
		push( @nvalues, $value );
		
	}
	
	
	return @nvalues;
}

sub mapCommonsImage {
	
	my @values = shift;
	my @nvalues;
	
	foreach my $value ( @values ) {
		
		$value =~s/«//g;
		$value =~s/»//g;
		$value =~s/"//g;
		$value =~s/\s/_/g;
		
		my $md5 = md5_hex( Encode::encode_utf8( $value ) );

		my ($part2) = $md5 =~/^(\S{2})/;
		my ($part1) = $md5 =~/^(\S{1})/;
		
		
		my $url = "https://upload.wikimedia.org/wikipedia/commons/$part1/$part2/$value";
		
		push( @nvalues, $url );
		
	}
	
	
	return @nvalues;
}

sub escapeQuotes {
	
	my $string = shift;
	
	
	$string =~ s/\"/\\\"/g;
	
	return $string;
}


sub uniq {
	my %seen;
	return grep { !$seen{$_}++ } @_;
}
