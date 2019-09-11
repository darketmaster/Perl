#!/usr/bin/perl
# Mauricio Lopez
#I3D EMCALI E.I.C.E.  E.S.P.

use strict;
use lib "./lib/";
use warnings;
use configloader;
use strict;
use Net::LDAP;
use Net::LDAP::Entry;
use JSON;

use Log::Dispatch;

my $log = Log::Dispatch->new(
	outputs => [
		[
			'File',
			min_level => 'debug',
			filename  => "$0.log",
			mode      => '>>',
			newline   => 1,
		],
		[ 'Screen', min_level => 'warning' ],
	],
);

#buffer is a valid json
my $ProcID = $$;
my ( @pairs, $pair, $name, $value, %FORM );
my ( $id_Request, $buffer, $_varSeparator );
my $_continue = 1;
########################################
#				               repuesta por defecto												 #
########################################
my $response;
$response->{type} = "info";
$response->{mess} = "nothing to do";
$response->{data} = "";

################################################
########             METHODS            ########
################################################
my $LDAPMethods = { 'search' => \&LDAPsearch, 
			'moddn' => \&LDAPmoddn, 
			'add' => \&LDAPadd,
			'compare'=>\&LDAPcompare,
			'delete'=>\&LDAPdelete,
			'modify'=>\&LDAPmodify,
		};

sub LDAPsearch {
	my ( $ldaph, $obj ) = @_;

	my $mesg = $ldaph->search( %{ $obj->{options} } );

	if ( !$mesg->code ) {
		my $hash = $mesg->as_struct();
		$response->{mess} = "search ok";
		$response->{data} = to_json($hash);
		$log->info( "RESPONSE OBJ: " . $response->{data} );
	}

	return $mesg;
}

sub LDAPmoddn {
	my ( $ldaph, $obj ) = @_;
	
	my $mesg = $ldaph->moddn(
	    			$obj->{dn},
					%{$obj->{options}}
		        );

		if ( !$mesg->code ) {
			$response->{mess} = $obj->{method} . " ok";
		}

		return $mesg;
	}
	
sub LDAPadd {
	my ( $ldaph, $obj ) = @_;

	my $mesg = $ldaph->add(
	    			$obj->{dn},
					attrs=>[%{$obj->{options}->{attrs}}]
		        );
   $log->info(  "METHOD ".$obj->{method});

		if ( !$mesg->code ) {
			$response->{mess} = $obj->{method} . " ok";
		}

		return $mesg;
	}

sub LDAPcompare {
	my ( $ldaph, $obj ) = @_;

   $log->info( "options:". to_json($obj->{options}));
	my $mesg = $ldaph->compare(
	    			$obj->{dn},
					%{$obj->{options}}
					#attr=>$obj->{options}->{attr},
					#value=>$obj->{options}->{value},
		        );
		        
   $log->info(  "METHOD ".$obj->{method});

		if ( $mesg->code ) {
			$response->{mess} = $obj->{method} . " ok";
			$response->{data} = $mesg->error;
		}

		return $mesg;
	}

sub LDAPdelete {
	my ( $ldaph, $obj ) = @_;

	my $mesg = $ldaph->delete(
	    			$obj->{dn},
					%{$obj->{options}->{attrs}}
		        );
   $log->info(  "METHOD ".$obj->{method});

		if ( !$mesg->code ) {
			$response->{mess} = $obj->{method} . " ok";
		}

		return $mesg;
	}

sub LDAPmodify {
	my ( $ldaph, $obj ) = @_;

	my $mesg = $ldaph->modify(
	    			$obj->{dn},
					%{$obj->{options}}
		        );
   $log->info(  "METHOD ".$obj->{method});

		if ( !$mesg->code ) {
			$response->{mess} = $obj->{method} . " ok";
		}

		return $mesg;
	}
########################################

	$log->info( "[" . getTime() . "] " . "INIT PROGRAM: " . $ProcID );

##### ARGV   0: ID , 1:key, 2:json
	if ( scalar(@ARGV) < 3 ) {
		$_continue = 0;
		$response->{mess} = "nothing to do, params number invalid!";
	}
	else {
		$log->info( "ID request: " . $ARGV[0] );
		$log->info( "key: " . $ARGV[1] );
		$log->info( "data: " . $ARGV[2] );
		$buffer = $ARGV[2];
		
		$log->info("BUFFER".$buffer);
		my $object = decode_json($buffer);

		foreach my $k ( keys %$object ) {
			$log->info( $k. "->" . $object->{$k});
			if ( $k =~ /options/i ) {
				foreach my $par ( keys %{ $object->{$k} } ) {
					$log->info(  "\t" . $par . "->" . $object->{$k}->{$par} );
				}
			}
		}

		##############ldap
		my $d = new configloader('config.conf');

		my $ldaperror = 0;
		my $ldpaipadd = $d->{_CONFIG}{LDAP}{ip};
		my $ldpapassw = $d->{_CONFIG}{LDAP}{pass};

		my $ldap = Net::LDAP->new($ldpaipadd) or $ldaperror = 1;
		$log->info( "[" . getTime() . "] " . "connecting to LDAP...[". ( $ldaperror ? "FAIL" : "OK" ). "]" );

		if ( !$ldaperror ) {
			my $mesg = $ldap->bind(
				"cn=Manager,o=emcali",
				password => $ldpapassw,
				version  => 3
			);

			if ( $mesg->code ) {
				$log->info( " An error occurred binding to the LDAP server --"  . $mesg->error );
				$response->{type} = "error";
				$response->{mess} =  " An error occurred binding to the LDAP server --"  . $mesg->error;
			}

			################################################
			#   LOGIC FOR METHODS
			################################################
			else {
				if ( defined $LDAPMethods->{ $object->{method} } ) 
				{
					$mesg =  $LDAPMethods->{ $object->{method} }->( $ldap, $object );
				}
				else {
					$log->info("Method not implemented...");
					$response->{type} = "error";
					$response->{mess} = "Method not implemented...";
				}

				if ( $mesg->code ) {
					$log->info( "An error occurred ". $object->{method} . " to the LDAP server  --" . $mesg->error );
					$response->{type} = "error";
					$response->{mess} =   "An error occurred "  . $object->{method} . " to the LDAP server --"  . $mesg->error;
				}

				$ldap->unbind();
			}
		}    #if !ldap  error

	}

##########################################################################################
###  CUSTOM FUNTIONS
##########################################################################################

	sub getTime {

		# Format message early to get accurate time-stamp...ype":"info
		my ( $sec, $min, $hour, $day, $mon, $year ) = localtime;
		$year += 1900;
		$mon++;
		my $strTime = sprintf( "%04d%02d%02d.%02d%02d%02d",
			$year, $mon, $day, $hour, $min, $sec );
		return $strTime;
	}

###RESPONSE STRING

	#$response->{data}=$hash;
	my $json_text = to_json($response);

	#my $json = JSON->new->allow_nonref;
	print $json_text;
