#!/opt/LifeKeeper/bin/perl

use Getopt::Std;

our $opt_u, $opt_r, $opt_k, $opt_p, $opt_a;
getopts("p:k:u:a");


if( ! defined ${opt_p} || ${opt_p} eq "" || ! defined ${opt_k} || ${opt_k} eq "" || ! defined ${opt_u} || ${opt_u} eq "")
{
	print STDERR "Usage:\n";
	print STDERR "\t./create_stacks.pl -u <Template S3 URL> -p <instance root password> -k <key file name> [-a]\n";
	print STDERR "Note: -a argument is required to actually create resources\n";
	print STDERR "Note: temporarily the s3 bucket must be pmerry-s3-32619 and the object must be AWS-Templates/\n";
	print STDERR "Note: Currently the passed key file must already be tracked by AWS.\n";
	exit 1;
}

my $url = ${opt_u};
my $pass = ${opt_p};
my $key = ${opt_k};


# TODO - Make this dynamically built, dont always use the same regions
my @regions=("us-west-2", "eu-west-1", "ap-southeast-1", "ca-central-1");

foreach my $reg (@regions)
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
