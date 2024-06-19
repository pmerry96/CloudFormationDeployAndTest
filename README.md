To use, run as follows:

./create_stacks.pl -u <s3 bucket url that points to the main template file> -p <instance root password> -k <key name> [-awdt]

Arguments:

 -u: the url for the main template file in the s3 bucket
 
 -p: instance root password, to be used on cluster nodes
 
 -k: the key file. Must be tracked by AWS


 Optional Arguments: 
 
 -a: "active". Actually creates resources. Without this argument, the parameter json files will be created and AWS CLI commands printed, but nothing will be created

 -w: Wait for completion, the script will stall until all stacks are in a finished state of deployment

 -d: delete on completion, the script will delete resources after all tests are run

 -t: wait on termination. the script will still until all stacks are finished deleting or failed deleting. 
