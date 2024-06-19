#!/opt/LifeKeeper/bin/perl

use Getopt::Std;
use List::Util qw/shuffle/;

our $opt_u, $opt_r, $opt_k, $opt_p, $opt_a;
getopts("p:k:u:n:a");


if( ! defined ${opt_p} || ${opt_p} eq "" || ! defined ${opt_k} || ${opt_k} eq "" || ! defined ${opt_u} || ${opt_u} eq "")
{
	print STDERR "Usage:\n";
	print STDERR "\t./create_stacks.pl -u <Template S3 URL> -p <instance root password> -k <key file name> [-a] [-n num_tests (default 4)]\n";
	print STDERR "Note: -a argument is required to actually create resources\n";
	print STDERR "Note: Currently the passed key file must already be tracked by AWS. Do not include the file extension in this name\n";
	exit 1;
}

my $num_tests = 4;
if( defined ${opt_n} && ${opt_n}){
	$num_tests = ${opt_n};
}

my $url = ${opt_u};
my $pass = ${opt_p};
my $key = ${opt_k};


# TODO - Make this dynamically built, dont always use the same regions
my @regions=("ap-northeast-2", "ap-south-1", "ap-southeast-1", "ap-southeast-2", "ca-central-1", "eu-central-1", "eu-north-1", "eu-west-1", "eu-west-2", "eu-west-3", "sa-east-1", "us-east-1", "us-east-2", "us-west-1", "us-west-2");

if($num_tests > scalar @regions){
	my $max = scalar @regions;
	print "Number of tests greater than number of regions, using $max tests instead\n";
}

my @regions_to_test = (shuffle(@regions))[0 .. $num_tests-1];



foreach my $reg (@regions_to_test)
{
	chomp(my $parmpath = `./create_parameters.pl -r $reg -p $pass -k $key -u $url`);
	my $awscmd="aws cloudformation create-stack --region $reg --stack-name SPSL-QuickStart-CLI-Test-$reg --template-url $url --parameters file://./$parmpath --capabilities CAPABILITY_IAM --on-failure DO_NOTHING";
	if( ${opt_a} ){
		my $output=`$awscmd`;
		print "AWS CLI Command \"$awscmd\" gave output:\n$output\n";
	}else{
		print "$awscmd\n";
	}
}

exit 0;
