# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Math-GAP.t'

#########################

use Test::More tests => 8;
BEGIN { use_ok('Math::GAP') };

#########################


my $command;
my $output;
my $line;
my $term;

my $gap_path = Math::GAP->get_GAP_path();
$gap_path =~ s/\s+-.+//;


SKIP: {
skip(
	'default path for GAP interpreter incorrect ('
	. $gap_path
	. ')'
	,6
	) if (!-x $gap_path);

ok($term=new Math::GAP,"object creation (launching GAP)");

is($term->get(),'',"reading empty buffer");

$command = 'Print("3");' ;
$term->code($command);
$output  = $term->get();
is($output, "3\n","simple code exec");


$command= 'l:=List([1..12],i->i^2);;l;' ;
$term->code($command);
$output  = $term->get() ;
$line=qq{[ }. join(", " ,map {$_**2} (1..12)). qq{ ]\n};
is($output,$line,"small computation");


$line    = '123456789 'x7 . '12345678' ;
$command = "Print(\"$line\");" ;
$term->code($command) ;
$output=$term->get();
is($output,$line."\n","a line of GAP output (=78 char)");


$line='123456789 'x7 . '123456789';
$command="Print(\"$line\");";
$term->code($command);
substr($line,78,3,"\\\n9\n");
$output=$term->get();

is($output,$line,"a long line of GAP output (>78 char)");

}

TODO :{
todo_skip "No yet tested",1;
Math::GAP->set_GAP_path('a/b -c');
my $pid = $$;
eval {$term= new Math::GAP;};
if($pid == $$) {exit;}

like($@,qr{^Problem with exec of 'a//b -c'},'a wrong GAP path');
}
