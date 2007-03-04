
package Math::GAP;

use 5.008000;
use strict;
use warnings;

use IO::Handle;	
use Exporter;

use Scalar::Util qw(refaddr);

use Carp;
use Socket;


our $VERSION = '0.02';

my $GAP_path  = '' ; #set at installation
my $GAP_exec  = '' ; #set at installation

my $PROMPT    = 'gap>' ;
my $ENDLINE   = ':_ENDCOM_:' ;

my %reader_of;
my %writer_of;
my %log_of;
my %pending_of;
my %cpid_of;


sub set_GAP_path{
    my $class=shift;
    my $command=shift;
    ($GAP_path,$GAP_exec)= $command =~ m[(.*/)([^/]*)];
}


sub get_GAP_path {
    my $class=shift;
    return $GAP_path.'/'.$GAP_exec;
}



sub start_GAP{
    my $self =shift;
    my $self_id = refaddr($self);

    socketpair(my $child,my $parent, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
		or  croak "socketpair: $!";
    $child->autoflush(1);
    $parent->autoflush(1);
    
    my $pid;
    
    if ($pid=fork){
              close $parent;
    } else {
    
              if(!defined($pid)) {croak "Cannot fork to start GAP";}
   
              close $child;
              
              open(STDIN,"<&",$parent) or croak "$!";
              open(STDOUT,">&",$parent) or croak "$!";
              open(STDERR,">",'/dev/null');

              exec ($GAP_path.'/'.$GAP_exec)
    	           or croak "Problem with exec of '$GAP_path/$GAP_exec'";
    }
    
    $cpid_of{$self_id} =$pid;
    $reader_of{$self_id}=$child;
    $writer_of{$self_id}=$child;
    return;
}


sub code{
	my ($self, $command, $hashref)=@_;
	my $self_id = refaddr($self);

	if (defined($hashref->{discard})) {
		my $bkp=$self->get();
		$log_of{$self_id}.=$bkp;
	#	print STDERR "backing up log (\n--\n$bkp\n--)\n";
	}
	
	print {$writer_of{$self_id}} q{Display("");} ;
	print {$writer_of{$self_id}} $command ;
	print {$writer_of{$self_id}}
	                 q{Display("");}
			.q{Display("} . $ENDLINE . q{");}
			.qq{\n} ;


	$pending_of{$self_id}++;

	
	if (defined($hashref->{discard})) {
		my $wiped=$self->get({last=>1});
	#	print STDERR "wiping out output (\n--\n$wiped\n--)\n";
	}	
}

sub get{
    my ($self, $hashref)=@_;
    my $self_id = refaddr($self);


    my $output='';
    while ($pending_of{$self_id} > 0){
    	while (my $line=readline($reader_of{$self_id}))
    	{
	#	chomp($line);
		$line =~ s/^($PROMPT\s*)+//ogix;
#		$line =~ s/\s* > \s*//gix;
		$output.= $line;
		last if $line =~ m/^$ENDLINE$/o;
    	}

	$pending_of{$self_id}--;

    }
  
    if (!defined($hashref->{keep})) {#$starter_of{$self_id}
	$output =~ s/(^\n)?$ENDLINE\n//gm;
    }
    if (defined($hashref->{last})){return $output;}
    my $copy=$log_of{$self_id}.$output;
    $log_of{$self_id}='';
    return $copy;
}

sub load {
      my ($self,$toload,$hashref)= @_;
  
      if (-r $toload) {
	  $self->code("Read(\"$toload\");",$hashref);
      } else {
	  $self->code("LoadPackage(\"$toload\");;",{discard=>1});
      }
}

sub new {
      my $class = shift;
      my $obj= bless \do{my $anon_scalar}, $class;;
      my $obj_id = refaddr($obj);

      $log_of{$obj_id}='';
      $pending_of{$obj_id}=0;

      $obj->start_GAP();
      $obj->code("\n",{discard=>1});
 #     $obj->get();
      return $obj;
}

sub DEMOLISH {
    my $self = shift;
    my $self_id = refaddr($self);

    $self->code('quit;');

    delete $log_of{$self_id};
    delete $pending_of{$self_id};
    delete $reader_of{$self_id};
    delete $writer_of{$self_id};
}


1;
__END__

=head1 NAME

Math::GAP - GAP interpreter controler for Perl

=head1 SYNOPSIS

  use Math::GAP;
  my $gap_term = new Math::GAP;
  $gap_term->load("guava");
  $gap_term->code("F:=PolynomialRing(GF(8));;Display(F);");
  print $gap_term->get();

=head1 ABSTRACT

GAP stands for Groups, Algorithms, Programming. It is a 
"System for Computational Discrete Algebra"
see L<http://www.gap-system.org/>.
This module defines (inside-out) objects that wrap a GAP interpreter. 
This allows to execute GAP code in Perl, precisly, inside the
interpreter and to read the output produced by the code.
One of the interest is to allow scripting with GAP, which is not a
feature of the standard GAP interpreter. 


=head1 DESCRIPTION


=head2 GAP

GAP (Groups, Algorithms, Programming) is a computational algebra software
(under GNU GPL) available from
L<http://www.gap-system.org/>. It comes
as an interpreted language and an interpreter. The interpreter does not
support scripting. 

=head2 WHAT CAN DO THIS MODULE

This module allows to create Perl objects that execute GAP code. When an object is created, a GAP interpreter is launched as a new process. 
The object can send GAP code to the interpreter and, separately,
collect its output.
A default GAP interpreter is set during the installation, but this can be
changed at run-time.

=head1 METHODS

=over

=item Path of the GAP interpreter: C<set_GAP_path()> and C<get_GAP_path()>

You can set change the default path set during installation

	Math::GAP->set_GAP_path('/my/path/to/gap');

You can even use command line option

	Math::GAP->set_GAP_path('/my/path/to/gap -b -o 515');

To get the current setting use

	Math::GAP->get_GAP_path();

=item Constructing an object: C<new()>

The constructor is simply named new

     	my $term=Math::GAP->new()

It starts a new GAP interpreter and returns a blessed reference. Each
object has his own interpreter. The interpreter is located using 
return value of C<get_GAP_path()> method.


=item Sending GAP code to the interpreter: C<code()> 

To execute GAP code there is the C<code()> method

	$obj->code($string,$option_hash_ref);

C<$string> must be valid GAP code (no verification is done before sending
the string to GAP).
The hash can contain a key 'discard'; in that case, the output of
the GAP interpreter, for $string only, will be discarded

	$obj->code('Display(3);',{discard=>1});
	print obj->get();                      #print nothing


=item Collecting the output: C<get()>

Use

	$obj->get()

to collect the result of previous commands sent to the interpreter.
Try to clean the output (removing promp 'gap>' ...). A call to get collect
all the previous commands, except for discarded ones.

	$obj->code('2+2;');
	$obj->code('3+3;',{discard=>1});
	$obj->code('4+4;');
	print obj->get();			#print 4\n8\n


=item Loading a file/package in the GAP interpreter: C<load()>

It is possible to load a file or package in the GAP interpreter using

	$obj->load($file_or_package_name,$option_hash_ref);

The $file_or_package_name argument is first tested to be a
readable file (-r). If not try to load as a package.
$option_hash_ref is used only for key 'discard' and in case of a file.

This is just a simple wraping for C<Read> and C<LoadPackage> GAP function.

=item Destructing an object

This is done automatically when the object goes out of scope.
The GAP interpreter is stopped at that time.

=item INTERNALS 

The C<new> method use C<start_GAP()> to creates the filehandles
and launchs the interpreter. Internal use only.

=back

=head1 DEPENDENCIES

This module requires these other modules and libraries:

=over

=item from Perl core modules :

 Carp,
 ExtUtils::MakeMaker,
 File::Find,
 IO::Handle,
 List::Util,
 Scalar::Util,
 Socket,
 Test::More.

=item a GAP interpreter.

It must be installed on your system. If it is installed
prior to this module installation, the installation try and set the default
path of the interpreter. Otherwise, you will have to set it using a
class methode.

=back

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.
Please report problems to Fabien Galand  (galand@cpan.org)
Patches are welcome.


=head1 SEE ALSO

See GAP documentation:
L<http://www.gap-system.org/Doc/doc.html>.

SAGE is an other way to get GAP:
L<http://sage.scipy.org/sage/>.


=head1 AUTHOR

Fabien Galand (galand@cpan.org).

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Fabien Galand (fgaland@cpan.org). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

