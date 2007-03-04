use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

use Carp;
use List::Util qw(first);

my $GAP_path; 
my $GAP_exec; 

if (defined($ENV{GAP})){

	($GAP_path,$GAP_exec)= $ENV{GAP} =~ m[(.*/)([^/]*)];
	print "Using gap from GAP env. variable\n";

} else {

	use File::Find;
	my @dir = split /:/, $ENV{PATH};
	sub wanted{
  		if($_ eq 'gap.sh'){
    		$GAP_path = $File::Find::dir . q{/};
    		$GAP_exec  = 'gap.sh';
  		} elsif ($_ eq 'sage'){
    		$GAP_path = $File::Find::dir . q{/};
    		$GAP_exec  = 'sage -gap';    
  		} elsif ($_ eq 'gap'){
    		$GAP_path = $File::Find::dir . q{/};
    		$GAP_exec  = 'gap';        
  		}
	}
	find(\&wanted,@dir);

}

if(!defined($GAP_path)){
  print "GAP interpreter not found\n";
  $GAP_path = prompt("gap path?");
  $GAP_exec = prompt("gap exec?");
}

(my $command="$GAP_path/$GAP_exec" ) =~ s/\s+-.+//;;
if(!-x $command) {
print <<"WARN";
Non executable GAP interpreter
Several tests won't be preformed
WARN
}

print <<"INFO";
Will use :
$GAP_path/$GAP_exec
as default GAP interpreter
INFO


my $file;
my $module_path = q(lib/Math/GAP.pm);

open ($file,"<",$module_path)
	or croak "Can't read from $module_path : $!";
my @lines=<$file>;
close $file;

#look for 'my $$var' in line $l and set it to $value
sub change_value {
	my ($var,$value)= @_[1..2];
	if($_[0]  =~ s/
		(
		 my \s+ \$$var \s+ = \s+
		)
		('[^']*')
		(
		\s*;\s*
		#set at installation
		)
		 /$1'$value'$3/x)
		 {return 1;}
		 
	return 0;
}

first {change_value($_,'GAP_path',$GAP_path)} @lines
	or die "GAP path not found!";
	
first {change_value($_,'GAP_exec',$GAP_exec)} @lines
	or die "GAP exec not found!";


open ($file,">",$module_path)
	or croak "Can't write to $module_path : $!";
foreach my $l (@lines) {print {$file} $l;}
close $file;


WriteMakefile(
    NAME              => 'Math::GAP',
    AUTHOR            => 'Fabien Galand <galand@cpan.org>',
    VERSION_FROM      => 'lib/Math/GAP.pm', # finds $VERSION
    ABSTRACT_FROM     => 'lib/Math/GAP.pm', # retrieve abstract from module
    PREREQ_PM         => {
                        'strict'              => 0,
			'warnings'            => 0,
			'Carp'                => 0,
  			'ExtUtils::MakeMaker' => 0,
  			'File::Find'          => 0,
			'List::Util'	      => 0,
  			'IO::Handle'          => 0,
  			'Scalar::Util'        => 0,
			'Socket'              => 0,
			'Test::More'          => 0,
  			    }, 
    dist               => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean              => { FILES => 'Math-GAP-*' },

);





