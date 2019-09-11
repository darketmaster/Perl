#!/usr/bin/perl -w
#configloader
#Author: Mauricio Lopez.

package configloader;
use strict; 
use warnings;

use Config::Std;

###Constructor
  sub new {
     my $this=shift; 
     my $class = ref($this) || $this; 
     
     my ($config_file) = @_;
     my $self={}; 
     read_config $config_file => $self ->{_CONFIG};

     bless $self, $class;
     return ($self);
  }
  
  # getter  
 sub getConfig {  
 	my $this=shift;
    #my $class = ref($_[0]) || $_[0];  
    return $this ->{_CONFIG};  
}
  
  
1;
  