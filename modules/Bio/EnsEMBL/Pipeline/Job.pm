# Object for storing an idlist and calculating diffences between lists
#
# Cared for by ensembl (ensembl-dev@ebi.ac.uk)
#
# Copyright ensembl
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::EnsEMBL::Pipeline::Job

=head1 SYNOPSIS


=head1 DESCRIPTION

object to hold information about and run a particular job

=head1 CONTACT

Post general queries to B<ensembl-dev@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Pipeline::Job;

use vars qw(@ISA);
use strict;
use warnings;
use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);


=head2 new

  Arg [1]   : list of args @args
  Function  : create a new Job
  Returntype: Bio::EnsEMBL::Pipeline::Job
  Exceptions: throws if not passed an input_id, taskname or module
  Caller    :
  Example   : my $job = Bio::EnsEMBL::Pipeline::Job->new(
                 -input_id => 'AC123801.1.1.23493',
							   -module => 'Bio::EnsEMBL::Pipeline::RunnableDB::RepeatMasker',
							   -taskname => 'RepeatMasker' );

=cut



sub new{
   my ($class, @args) = @_;
   my $self = bless {}, $class;

   $self->{'_dbID'} = undef;
   $self->{'_taskname'} = undef;
   $self->{'_input_id'} = undef;
   $self->{'_submission_id'} = undef;
   $self->{'_array_index'} = undef;
   $self->{'_parameters'} = undef;
   $self->{'_module'} = undef;
   $self->{'_stderr_file'} = undef;
   $self->{'_stderr_out'} = undef;
   $self->{'_status'} = undef;
   $self->{'_adaptor'} = undef;
	 $self->{'_job_name'} = undef;

   my ($dbID, $taskname, $input_id, $submission_id, $array_index,
			 $parameters, $module, $stderr_file, $stdout_file, $status,
			 $adaptor, $job_name) = $self->_rearrange([qw(dbID TASKNAME INPUT_ID
																				 SUBMISSION_ID ARRAY_INDEX PARAMETERS
                                         MODULE STDERR_FILE STDOUT_FILE STATUS
																				 ADAPTOR JOB_NAME)], @args);

   $self->dbID($dbID) if($dbID);
   if(!$taskname){
     $self->throw("Must define a taskname when creating a Job : $!");
   }else{
     $self->taskname($taskname);
   }
   if(!$input_id){
     $self->throw("Must define a input_id when creating a Job : $!");
   }else{
     $self->input_id($input_id);
   }
   $self->submission_id($submission_id) if($submission_id);
   $self->array_index($array_index) if($array_index);
	 $self->job_name($job_name) if($job_name);
   $self->parameters($parameters) if($parameters);
   if(!$module){
     $self->throw("Must define a module when creating a Job : $!");
   }else{
     $self->module($input_id);
   }
   $self->stderr_file($stderr_file) if($stderr_file);
   $self->stdout_file($stdout_file) if($stdout_file);
   $self->status($status) if($status);
   $self->adaptor($adaptor) if($adaptor);

   return $self;
}



=head2 accessor methods

  Arg [1]   : a string
  Function  : sets the string to the apropriate variable if it is passed 
  in and returns that value of that variable
  Returntype: a string
  Exceptions: none
  Caller    :
  Example   : my $module = $job->module;

=cut

sub dbID{
  my $self = shift;
	$self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

sub taskname{
  my $self = shift;
	$self->{'_taskname'} = shift if(@_);
  return $self->{'_taskname'};
}

sub input_id{
  my $self = shift;
	$self->{'_input_id'} = shift if(@_);
  return $self->{'_input_id'};
}

sub submission_id{
  my $self = shift;
	$self->{'_submission_id'} = shift if(@_);
  return $self->{'_submission_id'};
}

sub job_name {
	my $self = shift;
	$self->{'_job_name'} = shift if(@_);
	return $self->{'_job_name'};
}


sub array_index{
  my $self = shift;
	$self->{'_array_index'} = shift if(@_);
  return $self->{'_array_index'};
}

sub parameters{
  my $self = shift;
	$self->{'_parameters'} = shift if(@_);
  return $self->{'_parameters'};
}

sub module{
  my $self = shift;
	$self->{'_module'} = shift if(@_);
  return $self->{'_module'};
}

sub stderr_file{
  my $self = shift;
	$self->{'_stderr_file'} = shift if(@_);
  return $self->{'_stderr_file'};
}

sub stdout_file{
  my $self = shift;
	$self->{'_stdout_file'} = shift if(@_);
  return $self->{'_stdout_file'};
}

sub status{
  my $self = shift;
	$self->{'_status'} = shift if(@_);
  return $self->{'_status'};
}


=head2 adaptor

  Arg [1]   : Bio::EnsEMBL::Pipeline::DBSQL::JobAdaptor
  Function  : sets the passed in varible to be the job adaptor
  Returntype: Bio::EnsEMBL::Pipeline::DBSQL::JobAdaptor
  Exceptions: none
  Caller    : 
  Example   : $job->adaptor($jobadaptor);

=cut


sub adaptor{
  my $self = shift;
	$self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}




=head2 set_current_status

  Arg [1]   : string representing status
  Function  : updates status of a particular job in the job table
  Returntype: none
  Exceptions: throws if the object has no db connection in the form of
  an adaptor
  Caller    : 
  Example   : $self->set_current_status('RUNNING');

=cut



sub set_current_status{
  my ($self, $status) = @_;

  if(!$self->adaptor){
    $self->warn("Can't update the status of a Job if it doesn't have" .
								"a jobadaptor and a database connection" .
								$self->dbID . ":" . $self->taskname . ":" . $self->input_id);
  }else{
    $self->adaptor->update_status($self, $status);
  }
  $self->status($status);
}




=head2 run

  Arg [1]   : none
  Function  : runs which ever module that the Jobs has specified
  Returntype: none
  Exceptions: none
  Caller    : 
  Example   : $job->run;

=cut



sub run{
  my ($self) = @_;

  my $rdb;
  my $module = $self->module;
  eval {
    $module =~ s/::/\//g;
    require "${module}.pm";
    $module =~ s/\//::/g;
    $rdb = "${module}"->new
      (-input_id => $self->input_id,
	     -parameters => $self->parameters,);
  };

  if($@){
    print STDERR("Job creation for job ".$self->dbID.":".$self->taskname.":".
								 $self->input_id." failed $@");
    $self->set_current_status('FAILED');
  }

  eval{
    $self->set_current_status('READING');
    $rdb->fetch_input;
  };

  if($@){
    print STDERR("call to fetch_input for module ".$rdb." job ".
								 $self->dbID.":".$self->taskname.":".$self->input_id.
								 " failed $@");
    $self->set_current_status('FAILED');
  }

  eval{
    $self->set_current_status('RUNNING');
    $rdb->run;
  };

  if($@){
    print STDERR("call to run for module ".$rdb." job ".$self->dbID.":".
								 $self->taskname.":".$self->input_id." failed $@");
    $self->set_current_status('FAILED');
  }

  eval{
    $self->set_current_status('WRITING');
    $rdb->write_output;
    $self->set_curent_status('SUCCESSFUL');
  };

  if($@){
    print STDERR ("call to write output for module ".$rdb." job ".
									$self->dbID.":".$self->taskname.":".$self->input_id.
									" failed $@");
    $self->set_current_status('FAILED');
  }
}



1;
