# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Math-GAP.t'

#########################

use Test::More tests => 9;
BEGIN { use_ok('Math::GAP') };

#########################


my $command;
my $output;
my $line;
my $term;

my $gap_path = Math::GAP->get_GAP();
$gap_path =~ s{/sage\s+-.+}{/sage};


SKIP: {

skip(
     'default path for GAP interpreter ('
     . $gap_path
     . ') '
     . 'non executable'
     ,6
     ) 
    unless (-f $gap_path && -x $gap_path);

my $gap_command=join(" ",Math::GAP->get_GAP());
my $gap_banner = `echo "quit;\n"|$gap_command`;

skip(
     'exec for GAP seems to be something else than a GAP interpreter',
     6
     )
    unless ($gap_banner =~ /^GAP/ms);


ok($term=new Math::GAP,"object creation (launching default GAP)");


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

eval {
Math::GAP->set_GAP('/a/b', '-c');
};
like($@,qr{^Non executable GAP Interpreter},'a wrong GAP path yields a croak');


TODO :{
todo_skip "No yet tested",1;
Math::GAP->set_GAP('a/b', '-c');
my $pid = $$;
eval {$term= new Math::GAP;};
if($pid == $$) {exit;}

}
