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
#	-a: (optional) "Active". When specified, the script will actually create resources. 
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

# Determine number of tests to run
my $num_tests = 4;
if( defined ${opt_n} && ${opt_n}){
	$num_tests = ${opt_n};
}

# Determine if script waits for stack deployment to complete 
my $waitforcompleted=0;
if( defined ${opt_w} && ${opt_w}){
	$waitforcompleted=1;
}

# Determine if we delete after completing the script
my $delete_on_complete=0;
if(defined ${opt_d} && ${opt_d}){
	$delete_on_complete=1;
}

# Determine if script waits for stacks to finish deletion
my $wait_on_termination=0;
if(defined ${opt_t} && ${opt_t}){
	$wait_on_termination=1;
}

my $url = ${opt_u};
my $pass = ${opt_p};
my $key = ${opt_k};

my $onfailure = ( $delete_on_complete && ! $waitforcompleted) ? "DELETE" : "DO_NOTHING";

#my @regions=("ap-northeast-2", "ap-south-1", "ap-southeast-1", "ap-southeast-2", "ca-central-1", "eu-central-1", "eu-north-1", "eu-west-1", "eu-west-2", "eu-west-3", "sa-east-1", "us-east-1", "us-east-2", "us-west-1", "us-west-2");

my @regions=("us-west-2");

# if more tests than regions, only test once for each region. 
if($num_tests > scalar @regions){
	my $max = scalar @regions;
	$num_tests=$max;
	print "Number of tests greater than number of regions, using $max tests instead\n";
}

my @regions_to_test = (shuffle(@regions))[0 .. $num_tests-1];


# Create the stacks 
my $output="";
my %arns = ();
my $awscmd ="";
foreach my $reg (@regions_to_test)
{
	chomp(my $parmpath = `./create_parameters.pl -r $reg -p $pass -k $key -u $url`);
	$awscmd="aws cloudformation create-stack --region $reg --stack-name SPSL-QuickStart-CLI-Test2-$reg --template-url $url --parameters file://./$parmpath --capabilities CAPABILITY_IAM --on-failure $onfailure";
	if( ${opt_a} ){
		chomp($output=`$awscmd`);
		if($? == 0){
			$arns{$reg}=$output;
			print "AWS CLI Command \"$awscmd\" gave output:\n$output\n";
		}else{
			print "Stack failed to deploy with command \"$awscmd\", gave output:\n\"$output\"\n";
			$output="";
		}
	}else{
		$output="";
		print "$awscmd\n";
	}
	# If we got an ARN back from the AWS CLI, store it in a hash for later
	if( $waitforcompleted && $output ne "" ){ # && $output =~ m/^arn:aws:cloudformation/){
		$arns{$reg}="$output";	
	}
}

# if dont wait for complete, or we didnt use "active", exit now unless we delete on completion and also are active
if (! $waitforcompleted || ! ${opt_a}){
	exit 0 unless ($delete_on_complete && ${opt_a});
}

# If we did not get any ARNS back, nothing deployed. Exit with failure. 
if(! scalar keys %arns){
	print "No stacks were deployed successfully. Exiting\n";
	exit 1;
}

# Do the waiting on stacks to complete deployment
my %arns_to_check=%arns;
while (scalar keys %arns_to_check){
	foreach my $region (keys %arns_to_check){
		#check the status of the stack
		$awscmd="aws cloudformation describe-stacks --region $region --output text --stack-name $arns_to_check{$region} --query \"Stacks[*].StackStatus\"";
		chomp(my $status = `$awscmd`);

		# If stack status is complete, remove it from list to check and print success
		if( $status =~ m/_COMPLETE$/ && $status ne "DELETE_COMPLETE"){
			print "Stack $arns_to_check{$region} in region $region got SUCCESSFUL status $status\n";
			delete $arns_to_check{$region};
		# If stack status is failed, delete the stack if delete on complete is set and remove it from list of all arns and list of arns to check. 
		}elsif($status =~ m/_FAILED$/){
			print STDERR "STACK $arns{$region} got FAILED status $status.\n";
			delete $arns_to_check{$region};
			if($delete_on_complete){
				print STDERR "Deleting stack $arns{$region}\n";
				`aws cloudformation delete-stack --region $region --stack-name $arns{$region}`;
			}
			delete $arns{$region};
		}elsif($status eq "DELETE_COMPLETE"){
			print "Stack $arns_to_check{$region} in region $region was deleted and has status $status\n";
			delete $arns_to_check{$region};
			delete $arns{$region};
		}
	sleep 5;
	}
}

print "ALL STACKS DEPLOYMENT COMPLETED\n";


# Begin testing the stacks
print "##############################\n";
print "###BEGINNING TEST OF STACKS###\n";
print "##############################\n";
if( -e $key.".pem"){
	# Build name of the access key, it must be in the repo directory to use
	my $accesskey = $key.".pem";
	foreach my $region (keys %arns){
		print "PERFORMING TEST OF STACK IN $region\n";
		# get bastion host IP with this heinous AWS CLI command
		chomp(my $pubIP=`aws ec2 describe-instances --region $region --filters "Name=\"tag:cloudformation:stack-id\",Values=\"$arns{$region}\"" "Name=\"tag:aws:cloudformation:logical-id\",Values=\"BastionAutoScalingGroup\"" --query "Reservations[*].Instances[*].PublicIPAddress"`);
		
		my @resultsnode1 = ();
		my @resultsnode2 = ();;
		# If we have an IP and it is non-empty and it matches an IP, then continue testing
		if( defined $pubIP && $pubIP ne "" && $pubIP =~ m/\\d+\\.\\d+\\.\\d+\\.\\d+/){

			# Make a pinger and ping the system by the public IP
			my $pinger = Net::Ping->new();
			if( $pinger->ping($pubIP) ){
				
				# Put the necessary resources on the bastion host
				# If we could reach the system, send the access key to it and run the test script
				`scp -o "StrictHostKeyChecking no" -i $accesskey $accesskey ec2-user\@$pubIP:~/ 2>&1 > /dev/null`;
				`scp -o "StrictHostKeyChecking no" -i $accesskey test_deployment.sh ec2-user\@$pubIP:~/ 2>&1 > /dev/null`;
				
				
				# Run the tests on the cluster nodes and save results to put in a file
				my @resultsnode1 = split(/\n/, `ssh -o "StrictHostKeyChecking no" -i $accesskey ec2-user\@$pubIP -fq 'chmod 700 ~/test_deployment.sh; ~/test_deployment.sh $accesskey 10.0.0.100'`);
				my @resultsnode2 = split(/\n/, `ssh -o "StrictHostKeyChecking no" -i $accesskey ec2-user\@$pubIP -fq 'chmod 700 ~/test_deployment.sh; ~/test_deployment.sh $accesskey 10.0.32.100'`);
				
				
				# Output to the files specified, deleting old tests. 
				my $testoutput="./test-results/$region/SPSL01.txt";
				if( -e $testoutput ) {
					unlink $testoutput;
				}
				open(FH, '>', $testoutput) or (print STDERR "COULD NOT OPEN TEST OUTPUT FILE $testoutput - \"$!\"\n" and next);
				foreach my $node1line (@resultsnode1){
					print FH "$node1line\n";
				}
				close(FH);
				$testoutput="./test-results/$region/SPSL02.txt";
				if ( -e $testoutput ) {
					unlink $testoutput;
				}
				open(FH, '>', $testoutput) or (print STDERR "COULD NOT OPEN TEST OUTPUT FILE $testoutput\n - \"$!\"" and next);
				foreach my $node2line (@resultsnode2){
					print FH "$node2line\n";
				}
				close(FH);
			}
		}
		print "END TEST OF STACK IN $region\n";
		sleep 5;
	}
}

# If set to delete on completion, fire off the deletes

print "\n";
if($delete_on_complete){
	print "########################################\n";
	print "###BEGINNING DELETE OF CREATED STACKS###\n";
	print "########################################\n\n";
	foreach my $region (keys %arns){
		print "DELETING STACK $arns{$region} in $region\n";
		`aws cloudformation delete-stack --region $region --stack-name $arns{$region}`;
		my $ret = $?;
		my $retry = 3;
		# If aforementioned failed, retry
		while ( $ret != 0 && $retry > 0){
			`aws cloudformation delete-stack --region $region --stack-name $arns{$region}`;
			$ret = $?;
			$retry--;
			sleep 5; 
		}
	}
}else{
	exit 0;
}

print "All stacks queued for deletion\n";

%arns_to_check=%arns;
my $printedonce = 0;
while (scalar keys %arns_to_check){
	if(!$wait_on_termination || !$delete_on_complete ){
		last;
	}else{
		print "Wait on Stack deletion\n" unless $printedonce;
		$printedonce++;
	}
        foreach my $region (keys %arns_to_check){
                #check the status of the stack
                chomp(my $status = `aws cloudformation describe-stacks --region $region --output text --stack-name $arn{$region} --query "Stacks[*].StackStatus`);
                if( $status eq "DELETE_COMPLETE"){
                        print "Stack $arns_to_check{$region} in region $region got SUCCESSFULLY DELETED with status $status\n";
       	                delete $arns_to_check{$region};
                }elsif($status =~ m/_FAILED$/){
       	                print STDERR "STACK $arns{$region} got FAILED status $status.\n";
       	                delete $arns_to_check{$region};
       	        }
       		sleep 5;
	}
}


exit 0;
