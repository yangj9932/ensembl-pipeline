# Ensembl module for Bio::EnsEMBL::Analysis::Config::General
#
# Copyright (c) 2004 Ensembl
#
=head1 NAME

Bio::EnsEMBL::Analysis::Config::General

=head1 SYNOPSIS
    use Bio::EnsEMBL::Analysis::Config::General;
    use Bio::EnsEMBL::Analysis::Config::General qw();

=head1 DESCRIPTION

    General analysis configuration.

    It imports and sets a number of standard global variables into the
    calling package. Without arguments all the standard variables are set,
    and with a list, only those variables whose names are provided are set.
    The module will die if a variable which doesn\'t appear in its
    C<%Config> hash is asked to be set.

   The variables can also be references to arrays or hashes.

         Edit C<%Config> to add or alter variables.

         All the variables are in capitals, so that they resemble environment
         variables.

=head1 CONTACT

B<ensembl-dev@ebi.ac.uk>

=cut
         
package Bio::EnsEMBL::Analysis::Config::General;

use strict;
use vars qw(%Config);

%Config = (

           # binaries, libraries and data files
           BIN_DIR  => '/usr/local/ensembl/bin',
           
           ###### Modify DATA_DIR before running the pipeline test!!! #####
           DATA_DIR => '/your/cvs/checkout/dir/ensembl-pipeline/test_system/homo_sapiens/data',
           LIB_DIR  => '/usr/local/ensembl/lib',

           # Path where the parser and parameter files for FirstEF program are allocated
           PARAMETERS_DIR => '/vol/software/linux-i386/farm/lib/firstef/parameters/',
           PARSE_SCRIPT => '/vol/software/linux-i386/farm/lib/firstef/FirstEF_parser.pl',

           
           # The default directory the Runnable runs its analysis in
           ANALYSIS_WORK_DIR => '/tmp',
           ANALYSIS_REPEAT_MASKING => ['RepeatMask'],
  
           CORE_VERBOSITY => 'WARNING',
           LOGGER_VERBOSITY => 'OFF',
           #the two versbosity values control when commands like warning or logger_info
           #print to screen. The current settings give you most of what you want but
           #look at Bio::EnsEMBL::Utils::Exception and
           #Bio::EnsEMBL::Analysis::Tools::Logger for more info
           
          );



sub import {
    my ($callpack) = caller(0); # Name of the calling package
    my $pack = shift; # Need to move package off @_

    # Get list of variables supplied, or else all
    my @vars = @_ ? @_ : keys(%Config);
    return unless @vars;

    # Predeclare global variables in calling package
    eval "package $callpack; use vars qw("
         . join(' ', map { '$'.$_ } @vars) . ")";
    die $@ if $@;


    foreach (@vars) {
	if (defined $Config{ $_ }) {
            no strict 'refs';
	    # Exporter does a similar job to the following
	    # statement, but for function names, not
	    # scalar variables:
	    *{"${callpack}::$_"} = \$Config{ $_ };
	} else {
	    die "Error: Config: $_ not known\n";
	}
    }
}

1;
