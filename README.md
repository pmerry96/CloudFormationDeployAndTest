To use, run as follows:

./create\_stacks.pl -u <s3 bucket url that points to the main template file> -p <instance root password> -k <key name> [-a]

Arguments:
 -u: the url for the main template file in the s3 bucket
 -p: instance root password, to be used on cluster nodes
 -k: the key file. Must be tracked by AWS
 -a: "active". Actually creates resources. Without this argument, the parameter json files will be created and AWS CLI commands printed, but nothing will be created
