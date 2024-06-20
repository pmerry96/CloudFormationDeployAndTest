#!/opt/LifeKeeper/bin/perl

use Getopt::Std;
use File::Glob ':bsd_glob';

our $opt_r,$opt_p, $opt_k, $opt_u;

getopts('r:p:k:u:');

if( ! defined ${opt_r} || ${opt_r} eq "" || ! defined ${opt_p} || ${opt_p} eq "" || ! defined ${opt_k} || ${opt_k} eq "" || ! defined ${opt_u} || ${opt_u} eq ""){
	print STDERR "Usage:\n";
	print STDERR "./add_regions.pl -r <AWS_REGION> -p <instance password> -k <instance key> -u <S3 URL>\n";
	print STDERR "\n\t: EX: ./add_regions -r us-east-1 -p SamplePassword -k MyKey.pem -u https://Fake_Bucket.s3.REGION.amazonaws.com/OBJECT/templates/sios-protection-suite-main.template.yaml \n";
	exit 1;
}

my $region=${opt_r};
my $pass=${opt_p};
my $key=${opt_k};
my $url=${opt_u};
my $templatename = "sios-protection-suite-main.template.yaml";
my $jsonpartsdir = "./jsonparts/";

my @availability_zones=`aws ec2 describe-availability-zones --region $region --output text --query "AvailabilityZones[*].{ZoneName:ZoneName}" --filters Name="zone-type",Values="availability-zone"`;

if( scalar @availability_zones < 2){
	print STDERR "The region $region does not have enough availability zones to create the stack\n";
	exit 1;
}


# https://pmerry-s3-32619.s3.us-east-2.amazonaws.com/AWS-Templates/templates/sios-protection-suite-main.template.yaml
my @s3details=split(/[.\/]+/, $url);


if( $s3details[0] ne "https:" || $s3details[2] ne "s3" )
{
	print STDERR "The specified URL is not an s3 bucket\n";
	exit 1;
}

if( $s3details[-1] ne "yaml" )
{
	print STDERR "The specified URL is not a path to a .yaml file.\n";
}

my $s3bucket = $s3details[1];
my $s3region = $s3details[3];
my $s3object = "";
my $comreached = 0;
my $wholeobjectfound = 0;
foreach my $element (@s3details)
{
	if( $element eq "templates"){
		$wholeobjectfound = 1;
	}
	if($comreached && ! $wholeobjectfound){
		$s3object=$s3object.$element."/";
	}
	if(!$comreached && $element eq "com"){
		$comreached=1;
	}
}

my @last_three = splice(@s3details, -3);
my $filename = "";
foreach $i (@last_three){
	$filename=$filename.$i;
	if ( $i ne $last_three[-1]){
		$filename=$filename.".";
	}
}

if($filename ne $templatename){
	print STDERR "The URL does not point to the correct template file.\n\tGot:\t\"$filename\"\n\t Wanted:\t\"$templatename\"\n";
	exit 1;
}


#TODO - make this pick two availability zones that are not always the first two in the list
chomp(my $azstr="$availability_zones[0]");
chomp($azstr="$azstr,$availability_zones[1]");

my @jsonpartfiles = glob "$jsonpartsdir*";
my @jsonparts = ();

foreach my $jsonpartfile (@jsonpartfiles) 
{
	chomp(my $part = `cat $jsonpartfile`);
	push @jsonparts, $part;
}

my @parameters = split(/\n/, $jsonparts[0].$s3object.$jsonparts[1].$key.$jsonparts[2].$s3bucket.$jsonparts[3].$azstr.$jsonparts[4].$pass.$jsonparts[5].$s3region.$jsonparts[6]);

`mkdir -p ./generated-templates/$region`;
if ( $? != 0 )
{
	print STDERR "Could not mkdir $region. Aborting.\n";
	exit 1;
}
my $outfile = "./generated-templates/$region/cloudFormationParms.$region.json";

if( -e "$outfile")
{
	unlink $outfile;
}

open(FH, '>', $outfile) or die $!;
	
foreach my $line (@parameters)
{
	print FH $line."\n";
}
close(FH);

print "$outfile\n";

exit 0;
