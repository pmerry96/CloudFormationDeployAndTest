#!/opt/LifeKeeper/bin/perl

use Getopt::Std;
use List::Util qw/shuffle/;
use Net::Ping;

our $opt_u, $opt_r, $opt_k, $opt_p, $opt_a, $opt_w, $opt_d, $opt_t;
getopts("p:k:u:n:awdt");


# Check arguments and print usage
# Args are
# 	-p: Password for the instances
# 	-k: key file name for the instances (without the .<extension> on the file name)
# 	-u: URL for the template file, in an s3 bucket
# 	-n: (optional) the number of deployments to make, IE number of tests
# 	-w: (optional) wait for completion, script will loop until all stacks are either completed or failed. 
# 	-d: (optional) delete on completion. set -d to delete resources after script completes. Also deletes stacks on failure
# 	-t: (optional) wait on termination. Script will loop until all stacks are either deleted or failed to delete. 
if( ! defined ${opt_p} || ${opt_p} eq "" || ! defined ${opt_k} || ${opt_k} eq "" || ! defined ${opt_u} || ${opt_u} eq "")
{
	print STDERR "Usage:\n";
	print STDERR "\t./create_stacks.pl -u <Template S3 URL> -p <instance root password> -k <key file name> [-n num_tests (default 4)] [-awdt]\n";
	print STDERR "Note: -a argument is required to actually create resources\n";
	print STDERR "Note: Currently the passed key file must already be tracked by AWS. Do not include the file extension in this name\n";
	exit 1;
}

my $num_tests = 4;
if( defined ${opt_n} && ${opt_n}){
	$num_tests = ${opt_n};
}

my $waitforcompleted=0;
if( defined ${opt_w} && ${opt_w}){
	$waitforcompleted=1;
}

my $delete_on_complete=0;
if(defined ${opt_d} && ${opt_d}){
	$delete_on_complete=1;
}

my $wait_on_termination=0;
if(defined ${opt_t} && ${opt_t}){
	$wait_on_termination=1;
}

my $url = ${opt_u};
my $pass = ${opt_p};
my $key = ${opt_k};

my $onfailure = ( $delete_on_complete ) ? "DELETE" : "DO_NOTHING";


# TODO - Make this dynamically built, dont always use the same regions
#my @regions=("ap-northeast-2", "ap-south-1", "ap-southeast-1", "ap-southeast-2", "ca-central-1", "eu-central-1", "eu-north-1", "eu-west-1", "eu-west-2", "eu-west-3", "sa-east-1", "us-east-1", "us-east-2", "us-west-1", "us-west-2");
my @regions=("us-west-2");

if($num_tests > scalar @regions){
	my $max = scalar @regions;
	print "Number of tests greater than number of regions, using $max tests instead\n";
}

my @regions_to_test = (shuffle(@regions))[0 .. $num_tests-1];


my $output="";
my %arns = ();
my $awscmd ="";
foreach my $reg (@regions_to_test)
{
	chomp(my $parmpath = `./create_parameters.pl -r $reg -p $pass -k $key -u $url`);
	$awscmd="aws cloudformation create-stack --region $reg --stack-name SPSL-QuickStart-CLI-Test3-$reg --template-url $url --parameters file://./$parmpath --capabilities CAPABILITY_IAM --on-failure DO_NOTHING";
	if( ${opt_a} ){
		chomp($output=`$awscmd`);
		$arns{$reg}=$output;
		print "AWS CLI Command \"$awscmd\" gave output:\n$output\n";
	}else{
		$output="";
		print "$awscmd\n";
	}
	# If we got an ARN back from the AWS CLI, store it in a hash
	if( $waitforcompleted && $output ne "" && $output =~ m/^arn:aws:cloudformation/){
		$arns{$reg}="$output";	
	}
}

if (! $waitforcompleted || ! ${opt_a}){
	exit 0;
}

my $alldone = 0;
my %arns_to_check=%arns;
while (scalar keys %arns_to_check){
	foreach my $region (keys %arns_to_check){
		#check the status of the stack
		$awscmd="aws cloudformation describe-stacks --region $region --output text --stack-name $arns_to_check{$region} --query \"Stacks[*].StackStatus\"";
		chomp(my $status = `$awscmd`);
		if( $status =~ m/_COMPLETE$/ && $status ne "DELETE_COMPLETE"){
			print "Stack $arns_to_check{$region} in region $region got SUCCESSFUL status $status";
			delete $arns_to_check{$region};
		}elsif($status =~ m/_FAILED$/){
			print STDERR "STACK $arns{$region} got FAILED status $status.\n";
			delete $arns_to_check{$region};
			if($delete_on_complete){
				print STDERR "Deleting stack $arns{$region}\n";
				`aws cloudformation delete-stack --region $region --stack-name $arns{$region}`;
			}
			delete $arns{$region};
		}
	}
}

print "ALL STACKS DEPLOYMENT COMPLETED\n";


print "\n\nBEGINNING TEST OF STACKS\n\n";
if( -e $key.".pem"){
	my $accesskey = $key.".pem";
	foreach my $region (keys %arns){
		print "PERFORMING TEST OF STACK IN $region\n";
		#get bastion host IP
		chomp(my $pubIP=`aws ec2 describe-instances --region $region --filters "Name=\"tag:cloudformation:stack-id\",Values=\"$arns{$region}\"" "Name=\"tag:aws:cloudformation:logical-id\",Values=\"BastionAutoScalingGroup\"" --query "Reservations[*].Instances[*].PublicIPAddress`);
		if( defined $pubIP && $pubIP ne "" && $pubIP =~ m/\\d+\\.\\d+\\.\\d+\\.\\d+/){
			my $pinger = Net::Ping->new();
			if( $p->ping($pubIP) ){
				my @results = split(/\n/, `cat ./test_deployment.sh | ssh -i $accesskey ec2-user\@$pubIP`);
				foreach my $testline (@results){
					print "\t$testline\n";
				}
			}
		}
		print "END TEST OF STACK IN $region\n";
	}
}

if($delete_on_completion){
	foreach my $region (keys %arns){
		print "DELETING STACK $arns{$region} in $region\n";
		`aws cloudformation delete-stack --region $region --stack-name $arns{$region}`;
	}
}

print "All stacks queued for deletion\n";
print "Wait for deletion\n";

%arns_to_check=%arns;
while (scalar keys %arns_to_check){
        foreach my $region (keys %arns_to_check){
                #check the status of the stack
                chomp(my $status = `aws cloudformation describe-stacks --region $region --output text --stack-name $arn{$region} --query "Stacks[*].StackStatus`);
                if( $status eq "DELETE_COMPLETE"){
                        print "Stack $arns_to_check{$region} in region $region got SUCCESSFULLY DELETED with status $status";
                        delete $arns_to_check{$region};
                }elsif($status =~ m/_FAILED$/){
                        print STDERR "STACK $arns{$region} got FAILED status $status.\n";
                        delete $arns_to_check{$region};
                }
        }
	if(!$wait_on_termination){
		last; 
	}
}

exit 0;
