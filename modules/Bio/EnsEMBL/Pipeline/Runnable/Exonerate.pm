#!/usr/local/bin/perl -w

#
#
# Cared for by Val Curwen  <vac@sanger.ac.uk>
#
# Copyright Val Curwen
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::Runnable::Exonerate

=head1 SYNOPSIS

    my $obj = Bio::EnsEMBL::Pipeline::Runnable::Exonerate->new(
                                             -genomic => $genseq,
                                             -est     => $estseq 
                                             );
    or
    
    my $obj = Bio::EnsEMBL::Pipeline::Runnable::Exonerate->new()

=head1 DESCRIPTION

Exonerate is a fast EST:genomic alignment program written by Guy Slater.
This object runs exonerate over input EST and genomic sequences, and stores the 
exonerate matches as an array of Bio::EnsEMBL::FeaturePair

The passed in $genseq and $estseq are references to arrays of Bio::Seq; exonerate 
runs faster if given multiple query sequences at once. 

=head2 Methods:

 new,
 genomic_sequence,
 est_sequence,
 run,
 output.

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Pipeline::Runnable::Exonerate;

use vars qw(@ISA);
use strict;
# Object preamble - inherits from Bio::Root::Object;

use Bio::EnsEMBL::Pipeline::RunnableI;
use Bio::EnsEMBL::FeaturePair;
use Bio::EnsEMBL::SeqFeature;
use Bio::EnsEMBL::Analysis;
#compile time check for executable - won't work till centrally installed ...
use Bio::EnsEMBL::Analysis::Programs qw(exonerate); 
use Bio::PrimarySeq;
use Bio::SeqIO;
use Bio::Root::Object;

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableI Bio::Root::Object );

sub _initialize {
  my ($self,@args) = @_;
  my $make = $self->SUPER::_initialize(@_);    
  
  $self->{'_fplist'} = []; #create key to an array of feature pairs
  $self->{_clone}  = undef;        #location of Bio::Seq object
  $self->{_exonerate} = undef;     #location of exonerate
  $self->{_workdir}   = undef;     #location of temp directory
  $self->{_filename}  =undef;      #file to store Bio::Seq object
  $self->{_estfilename} = undef;   #file to store EST Bio::Seq object
  $self->{_results}   =undef;      #file to store results of analysis
  $self->{_protected} =[];         #a list of files protected from deletion
  $self->{_arguments} =undef;      #arguments for exonerate
  
  my( $genomic, $est, $exonerate, $arguments ) = 
    $self->_rearrange(['GENOMIC','EST', 'EXONERATE', 'ARGS'], @args);
  
  $self->genomic_sequence($genomic) if $genomic; #create & fill key to Bio::Seq
  $self->est_sequence($est) if $est; #create & fill key to Bio::Seq
  if ($exonerate) 
    {   $self->exonerate($exonerate) ;}
  else
    {   
      eval 
        { $self->exonerate($self->locate_executable('exonerate')); };
      if ($@)
	# need a central installation ...
        { $self->throw("Can't find exonerate!"); }
    }
  if ($arguments) 
    {   $self->arguments($arguments) ;}
  
  return $self; # success - we hope!
}

#################
# get/set methods 
#################
=head2 genomic_sequence

    Title   :   genomic_sequence
    Usage   :   $self->genomic_sequence($seq)
    Function:   Get/set method for genomic sequences
    Returns :   reference to an array of Bio::Seq
    Args    :   reference to an array of Bio::Seq

=cut

sub genomic_sequence {
  my( $self, $value ) = @_;    
  
  print STDERR "In this function!!!\n";

  if ($value) {
      $value->isa("Bio::PrimarySeqI") || $self->throw("Input isn't a Bio::PrimarySeqI");
      
      $self->{'_genomic_sequence'} = $value;
      $self->filename($value->id.".$$.seq");
      $self->results($self->filename.".exonerate.out");
  }
  # returns a Bio::Seq
  return $self->{'_genomic_sequence'};
}

=head2 est_sequence

    Title   :   est_sequence
    Usage   :   $self->est_sequence($seq)
    Function:   Get/set method for est sequences
    Returns :   reference to an array of Bio::Seq
    Args    :   reference to an array of Bio::Seq

=cut

sub est_sequence {
  my( $self, $value ) = @_;

  if ($value) {
    # $value should be a reference to an array of Bio::Seq objects. These need to be written out to file
    ref($value) eq 'ARRAY' || $self->throw("Expected an array reference, not $value");
    foreach my $est(@$value) {
      $est->isa("Bio::PrimarySeqI") || $self->throw("Input isn't a Bio::PrimarySeqI");
    }
    $self->{'_est_sequences'} = $value;
    $self->estfilename($value->[0]->id.".$$.est.seq");
    
  }
  
  #NB ref to an array of Bio::Seq
  return $self->{'_est_sequences'};
}

=head2 exonerate

    Title   :   exonerate
    Usage   :   $self->exonerate('/path/to/executable')
    Function:   Get/set method for exonerate executable path
    Returns :   
    Args    :   

=cut

sub exonerate {
  my ($self,$arg) = @_;
  
  if (defined($arg)) {
    $self->{_exonerate} = $arg;
  }
  return $self->{_exonerate};
}

=head2 arguments

    Title   :   arguments
    Usage   :   $self->est_sequence($args)
    Function:   Get/set method for exonerate arguments
    Returns :   
    Args    :   

=cut

sub arguments {
  my ($self, $args) = @_;
  if ($args)
    {
      $self->{_arguments} = $args ;
    }
  return $self->{_arguments};
}


=head2 estfilename

    Title   :   estfilename
    Usage   :   $self->estfilename($filename)
    Function:   Get/set method for estfilename
    Returns :   
    Args    :   

=cut

sub estfilename {
  my ($self, $estfilename) = @_;
  $self->{_estfilename} = $estfilename if ($estfilename);
  return $self->{_estfilename};
}

=head2 run

  Title   : run
  Usage   : $self->run()
            or
            $self->run("genomic.seq", "est.seq")
  Function: Runs exonerate and stores results as FeaturePairs
  Returns : TRUE on success, FALSE on failure.
  Args    : Temporary filenames for genomic and est sequences

=cut

sub run {
  my ($self, @args) = @_;
  $self->workdir('/tmp');
  
  
  #check inputs
  my $genomicseq = $self->genomic_sequence ||
    $self->throw("Genomic sequences not provided");
  my $estseq = $self->est_sequence ||
    $self->throw("EST sequences not provided");
  
  #extract filenames from args and check/create files and directory
  my ($genname, $estname) = $self->_rearrange(['genomic', 'est'], @args);
  my ($genfile, $estfile) = $self->_createfiles($genname, $estname, $self->workdir());
  
  #use appropriate Bio::Seq method to write fasta format files
  {
    my $genOutput = Bio::SeqIO->new(-file => ">$genfile" , '-format' => 'Fasta')
      or $self->throw("Can't create new Bio::SeqIO from $genfile '$' : $!");
    my $estOutput = Bio::SeqIO->new(-file => ">$estfile" , '-format' => 'Fasta')
      or $self->throw("Can't create new Bio::SeqIO from $estfile '$' : $!");
    
    #fill inputs
    $genOutput->write_seq($genomicseq);

    foreach my $eseq(@$estseq) {
      $estOutput->write_seq($eseq);
    }
  }
  
  $self->results($self->workdir()."/".$self->results());
  my $exonerate_command = $self->exonerate() . " --cdna $estfile --genomic $genfile >" . $self->results();
  
  eval {
    print (STDERR "Running command $exonerate_command\n");
    $self->throw("Error running exonerate on ".$self->filename."\n") 
      if (system ($exonerate_command)); 
    $self->parse_results();
  };  
  
  #clean up temp files
  $self->_deletefiles($genfile, $estfile);
  if ($@) {
    $self->throw("Error running exonerate :$@ \n");
  } 
  else {
   return (1);
  }
}

=head2 parse_results
  
    Title   :   parse_results
    Usage   :   $obj->parse_results($filename)
    Function:   Parses exonerate output to give a set of features
                parsefile can accept filenames, filehandles or pipes (\*STDIN)
    Returns :   none
    Args    :   optional filename

=cut

sub parse_results {
  my ($self, $filehandle) = @_;

  # some constant strings
  my $source_tag  = "exonerate";
#  my $primary_tag = "similarity";
  my $resfile = $self->results();
  if (-e $resfile) {
    open (EXONERATE, "<$resfile") or $self->throw("Error opening ", $resfile, " \n");#
    $filehandle = \*EXONERATE;
  }
  else { #it'a a filehandle
    $filehandle = $resfile;
  }
  
  #read output
  my $queryname = "";
  while (<$filehandle>) {
    
    if ($_ =~ /exonerate/) {
      next if($_ =~ /^Message/);
      

      #split on whitespace
      my @elements = split;

      if( $elements[1] ne 'exonerate' ) { next; }

      if($_ =~ /query \"(\w+)\"/) {
	$queryname = $1;
      }

      #extract values from output line [0] - [7]
      my $primary_tag = $elements[2];
      my $f1score  = $elements[5];
      if ($f1score eq ".") { $f1score = 0; } # only genes have a score
      my $f1start  = $elements[3];
      my $f1end    = $elements[4];
      my $f1id     = $elements[0];
      # start & end on EST sequence are not currently given by exonerate output ...
      my $f2start  = 1;
      my $f2end    = 1;
      
      # est seqname
      my $f2id     = $queryname;
      my $f1source = $source_tag;
      my $f2source = $source_tag;
      my $f1strand = 1;
      if ($elements[6] eq '-') {
	$f1strand = -1;
      }
      # currently doesn't deal well with - strand ... genes
      #	  my $f2strand = $estOrientation;
      my $f2strand = $f1strand;
      my $f1primary = $primary_tag;
      my $f2primary = $primary_tag;
      
      #create array of featurepairs              
      $self->_createfeatures ($f1score, $f1start, $f1end, $f1id, 
      				$f2start, $f2end, $f2id, $f1source, 
      				$f2source, $f1strand, $f2strand, 
      				$f1primary, $f2primary);
    }    
  }
  close($filehandle);
}

=head2 output

  Title   : output
  Usage   : $self->output
  Function: Returns results of exonerate as array of FeaturePair
  Returns : An array of Bio::EnsEMBL::FeaturePair
  Args    : none

=cut

sub output {
  my ($self) = @_;
  return @{$self->{'_fplist'}};
}

=head2 _create_features

  Title   : _create_features
  Usage   : $self->_create_features($f1score, $f1start, $f1end, $f1id, 
				    $f2start, $f2end, $f2id, $f1source, 
				    $f2source, $f1strand, $f2strand, 
				    $f1primary, $f2primary)
  Function: Returns results of exonerate as array of FeaturePair
  Returns : Nothing, but $self->{_fplist} contains a new FeaturePair
  Args    : 

=cut

sub _createfeatures {
  my ($self, $f1score, $f1start, $f1end, $f1id, $f2start, $f2end, $f2id,
      $f1source, $f2source, $f1strand, $f2strand, $f1primary, $f2primary) = @_;

  #create analysis object
  my $analysis_obj    = new Bio::EnsEMBL::Analysis
    (-db              => "none",
     -db_version      => "none",
     -program         => "exonerate",
     -program_version => "1",
     -gff_source      => $f1source,
     -gff_feature     => $f1primary,);
  
  
  #create features

  #print STDERR "Creating with $f1start $f1end \n";

  my $feat1 = new Bio::EnsEMBL::SeqFeature  (-start      =>   $f1start,
					     -end         =>   $f1end,
					     -seqname     =>   $f1id,
					     -strand      =>   $f1strand,
					     -score       =>   $f1score,
					     -percent_id  =>   $f1score, 
					     -source_tag  =>   $f1source,
					     -primary_tag =>   $f1primary,
					     -analysis    =>   $analysis_obj );
  
  my $feat2 = new Bio::EnsEMBL::SeqFeature  (-start       =>   $f2start,
					     -end         =>   $f2end,
					     -seqname     =>   $f2id,
					     -strand      =>   $f2strand,
					     -score       =>   $f1score,
					     -percent_id  =>   $f1score, 
					     -source_tag  =>   $f2source,
					     -primary_tag =>   $f2primary,
					     -analysis    =>   $analysis_obj );
  #create featurepair
  my $fp = new Bio::EnsEMBL::FeaturePair  (-feature1 => $feat1,
					   -feature2 => $feat2) ;
  
  if ($fp) {
    $self->throw("Can't validate") unless $fp->validate();
    push(@{$self->{'_fplist'}}, $fp);
  }
}

#####################################
# creating and clearing up temp files
#####################################

# a lot of this is shared with eg Vert_Est2Genome. Need a common parent ...
sub _createfiles {
  my ($self, $genfile, $estfile, $dirname)= @_;
  
  #check for diskspace
  my $spacelimit = 0.01; # 0.01Gb or about 10 MB
  my $dir ="./";
  unless ($self->_diskspace($dir, $spacelimit)) 
    {
      $self->throw("Not enough disk space ($spacelimit Gb required)");
    }
  
  #if names not provided create unique names based on process ID    
  $genfile = $self->_getname("genfile") unless ($genfile);
  $estfile = $self->_getname("estfile") unless ($estfile);    
  
  # Should check we can write to this directory 
  $self->throw("No directory $dirname") unless -e $dirname;
  
  return ($genfile, $estfile);
}

sub _getname {
  my ($self, $typename) = @_;
  return  $typename."_".$$.".fn"; 
}

sub _diskspace {
  my ($self, $dir, $limit) =@_;
  my $block_size; #could be used where block size != 512 ?
  my $Gb = 1024 ** 3;
  
  open DF, "df $dir |" or $self->throw ("Can't open 'du' pipe");
  while (<DF>) 
    {
      if ($block_size) 
        {
	  my @L = split;
	  my $space_in_Gb = $L[3] * 512 / $Gb;
	  return 0 if ($space_in_Gb < $limit);
	  return 1;
        } 
      else 
        {
	  ($block_size) = /(\d+).+blocks/i
	    || $self->throw ("Can't determine block size from:\n$_");
        }
    }
  close DF || $self->throw("Error from 'df' : $!");
}

sub _deletefiles {
  my ($self, @files) = @_;
  
  my $unlinked = unlink(@files);
  
  if ($unlinked == @files) {
    return 1;
  } else {
    my @fails = grep -e, @files;
    $self->throw("Failed to remove @fails : $!\n");
  }
}



