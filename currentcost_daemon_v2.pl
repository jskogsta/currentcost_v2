#!/opt/local/bin/perl -w
#
# File:			currentcost_daemon_v2.pl
# Version info:	This version is the basic one, which only gets the raw data and transforms to BAM & MySQL data. It does not create the
#				added information that relates to watt_seconds, which can be used for the data presentation & assumptions. The background for
#				that requirement is that the Currentcost sends samples at varying times. Hence we have to normalise the data with this in 
#				mind.
# Project: 		Currentcost perl daemon to be run on a MacMini Yosemite (previous on a Tonidoplug V1). 
# Purpose: 		The purpose of this perl daemon is to continously monitor the inbound /dev/tty.PL2303-00004014 (Currentcost USB cable) channel for XML data that represents energy
#				samples, which will have to be parsed and pumped into a MySQL database. This database will serve as the data store from which 
#				the front-end will derive its data to present useful graphs, events, triggers etc.
# Filename: 	ccost.pl
# Updates:
#		27/9/2016 : Updated with invoking local curl command direct from the perl command. Works ok also into WSO2DAS.
#		24/7/2015 : Added in proper error handling on the serial XML document parsing.
#		16/9/2016 : Had to update the tty driver name as the new Prolific driver name had changed with a new version that was installed. 
# By whom?:		Jorgen Skogstad ( jorgen@skogstad.com )
#
# Information relevant to the program given below: 
# ---------------------------------------------------
#
# The following XML structure is the structured output given by the Currentcost meter
# as and when the sensor sends a trigger event. This is what we have to parse later, and
# extract then the TIME, CHANNEL and WATTAGE, which will be used to pump into the MySQL
# database.
#
# This was derived from the Currentcost XML spec here: http://www.currentcost.com/cc128/xml.htm & http://www.currentcost.com/download/Envi%20XML%20v19%20-%202011-01-11.pdf
# The EnviR can be paired against 10 sensors at max, and is a manual process. As such, the sensor ID uniquely identifies the bespoke sensor. See here: http://www.currentcost.com/product-cc128-installation.html
# In my basic build, I only have 1 sensor, which is for the whole of house (sensor 0). The three channels are got three phase power, but in most instances this is not required, and likely can only look at channel 1 in the xml.
# Info: "With the Envi model up to 3 channels for 3-phase power, or a secondary meter box, can be monitored. These will appear as the endpoints ch.1, ch.2 and ch.3"
# From: http://www.dbzoo.com/livebox/xap_currentcost
#
#	<msg>
#	   <src>CC128-v0.11</src>
#	   <dsb>00089</dsb>
#	   <time>13:02:39</time>
#	   <tmpr>18.7</tmpr>
#	   <sensor>1</sensor>
#	   <id>01234</id>
#	   <type>1</type>
#	   <ch1>
#	      <watts>00345</watts>
#	   </ch1>
#	   <ch2>
#	      <watts>02151</watts>
#	   </ch2>
#	   <ch3>
#	      <watts>00000</watts>
#	   </ch3>
#	</msg>
#
#<msg>
#	<src>CC128-v1.31</src>
#	<dsb>01360</dsb>
#	<time>15:07:50</time>
#	<hist>
#		<dsw>01362</dsw>
#		<type>1</type>
#		<units>kwhr</units>
#		<data><sensor>0</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>1</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>2</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>3</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>4</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>5</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>6</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>7</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>8</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		<data><sensor>9</sensor><h424>0.000</h424><h422>0.000</h422><h420>0.000</h420><h418>0.000</h418></data>
#		</hist>
#</msg>
#
#
#<msg>
#<src>CC128-v1.31</src>
#<dsb>01360</dsb>
#<time>15:07:39</time>
#<tmpr>20.6</tmpr>
#<sensor>0</sensor>
#<id>03995</id>
#<type>1</type>
#<ch1>
#	<watts>00505</watts>
#</ch1>
#</msg>
#
# Note on the use of WSO2 BAM as a container for data store: 
# ----------------------------------------------------------
# Given this script is experimental at best, this will evolve. The current version (as of October 2014) commits to MySQL as well as Cassandra. The reason for this is to use
# Cassandra/HIVE to create dynamically updated MySQL tables that can be used to display data in close to "real time" manner. This will be likely done using a local web front end
# to start with. Perhaps to sync to mobile device eventually ... 
#
# .. and I am considering playing around with Couchbase too as a container. Need to figure out how that will work, but reason for this is that Couchbase already deals with the 
# distributed ongoing sync operations, which is a bit of a drag with a RDBMS. However, not figured out how you would build the mobile application to interact with say an on device
# Couchbase to represent the data visually. Perhaps something to look at in the long term .. 
#
# Some further notes on how this scripts functions:
# ---------------------------------------------------
#
# The data above is sent over the serialport from the Currentcost as a single line (see url: http://www.jibble.org/currentcost/). Hence simple to parse based on inbound serial port loop!
# It seems like the Curentcost EnviR meter will send out a message of the type above for each sensor message that is received from the various sensors.
#
# The following is the simple MySQL database table that holds the sample data. This can be used in phpMyAdmin to create the base table that is required for this to work. 
#
#
#--
#-- Table structure for table `CurrentCostDataSamples_MySQL_Dump`
#--
#
# CREATE TABLE `CurrentCostDataSamples_MySQL_Dump` (
#   `messageRowID` varchar(100) NOT NULL,
#   `payload_sensor` tinyint(4) DEFAULT NULL,
#   `messageTimestamp` bigint(20) DEFAULT NULL,
#   `payload_temp` float DEFAULT NULL,
#   `payload_timestamp` bigint(20) DEFAULT NULL,
#   `payload_timestampmysql` datetime DEFAULT NULL,
#   `payload_watt` int(11) DEFAULT NULL,
#   `payload_wattseconds` bigint(20) DEFAULT NULL,
#   PRIMARY KEY (`messageRowID`)
# ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
#
# - Starting the program can be done with a simple shell command (but remember to update the directory statements). Note that the Perl program will daemonise and run in the background.
# > root@TonidoPlug:~/projects/ccost# perl ./currentcost_daemon.pl
# - If you have enabled logging (by turning the switch further down to 1), you can tail the log file as exemplified here: 
# > root@TonidoPlug:~/projects/ccost# tail -f ./ccost.log
# - If you are running against a local file to test this (which also have to be turned on by the right switch further down), you can push another XML sample onto the inbound file like this: 
# > root@TonidoPlug:~/projects/ccost# cat ccost_data_sample.xml >> ccost.xml


use strict;
use warnings;
use Device::SerialPort qw( :PARAM :STAT 0.07 );	# Uncomment when using on Tonidoplug
use XML::LibXML;
use DateTime::Format::MySQL;
use 5.12.5;
use Time::localtime; 
use DateTime;
use DBI; 
use File::Tail;						# Use to test local file based input VS ongoing serial port input.
use Data::Dumper;
use Log::Log4perl qw(:easy);
use Proc::Daemon;
use LWP::UserAgent;
use File::Slurp;
use Try::Tiny;

# Daemonise the Perl program to log the Currentcost data to MySQL
#Proc::Daemon::Init;
my $continue = 1;
#$SIG{TERM} = sub { $continue = 0 };

# Initialize Logger
my $log_conf = q(
   log4perl.rootLogger              = DEBUG, LOG1
   log4perl.appender.LOG1           = Log::Log4perl::Appender::File
   log4perl.appender.LOG1.filename  = /Users/jskogsta/projects/currentcost_v2/log/ccost.log
   log4perl.appender.LOG1.mode      = append
   log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
   log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
);
Log::Log4perl::init(\$log_conf);

my $logger = Log::Log4perl->get_logger();

$logger->info("Initializing script .......");

# Use local file for inbound test OR serial port
my $local_or_serial = 1;	# 0 = local file, 1 = serial port
my $local_xmlfile = "/Users/jskogsta/projects/currentcost_v2/ccost.xml";
# Are we going to use debug logging, or not?
my $logging = 0;			# 0 = logging off, 1 = logging on. 
my $xml_parse_error = 0;			# 0 = normal run condition. 1 = error found. 
my $cc_last_sample_epoch_time = 0;		# storing the last epoch which was the last time the CC sent a sample. Used to calculate watt_seconds

# invoke the ConnectToMySQL sub-routine to make the database connection
my $db_connection = ConnectToMySql(my $database);

# Given we daemonise the program, it will just continue to loop through from there and continue pumping data to MySQL ..
while ($continue) {

	if ($local_or_serial == 0) {
			# Testing against local file
			if ($logging == 1) { $logger->info("Testing against local file: $local_xmlfile") };

			# Max time to wait between checks. File::Tail uses an adaptive
			# algorithm to vary the time between file checks, depending on the
			# amount of data being written to the file. This is the maximum
			# allowed interval.
			my $maxinterval = 1;

			my $file = File::Tail->new(name=>$local_xmlfile, maxinterval=> $maxinterval, adjustafter=>3) or ( say "Dying!" && die );

			# Loop as long as we keep getting lines from the file
			while (defined(my $line = $file->read)) {
				if ($logging == 1) { $logger->info("Input XML: ", $line) };
				&parse_cc_xml($line, $db_connection);

			}

		} else {
			# Production; using the serial port
			#my $PORT = "/dev/tty.PL2303-00004014";		# This is the USB driver for the white USB Currentcost cable.
			#my $PORT = "/dev/tty.usbserial"; 		# This is the new name for the Prolific USB2Serial driver (updated 16/9/2016 - JS)
			my $PORT = "/dev/tty.Repleo-PL2303-00002014";	# For some reason the El Capitain Prolofic driver did not work. Used the open source driver, which seems to work. (updated 19/9/2016 - JS)

			if ($logging == 1) { $logger->info("Running production against: $PORT") };

			# Connect to Current Cost device
			# This is the serial port in the Tonidoplug - uncomment when using this script on the Tonidoplug with the Currentcost data cable
			my $ob = Device::SerialPort->new($PORT) || die "Can't open $PORT: $!\n";
			$ob->baudrate(57600);
			$ob->write_settings;

			# Continously loop through serial input from currentcost // START
			open(SERIAL, "+>$PORT") or die "$!\n";

			while (my $line = <SERIAL>) {
				&parse_cc_xml($line, $db_connection);
			}		

		}
}

sub parse_cc_xml {

	my $logger = Log::Log4perl->get_logger();

	# Create a new XML parser
	my $parser = XML::LibXML->new();
	# Catch any XML parser errors in an eval (URL: http://perl.mines-albi.fr/perl5.6.1/site_perl/5.6.1/sun4-solaris/XML/LibXML/Parser.html ), such that the program does not die.

	my $doc; 

	# handle errors in parsing the XML serial input with a catch handler
	eval {
		$doc = $parser->parse_string( $_[0] );		# parse serial xml input
	};
	return if $@;
	
	# This XML tag only exists in the 'simple' XML file; e.g. the one that has the energy sample, and not the one that is the aggregate. Hence lets use this to differentiate whether this is a 
	# sample that we want to commit to the database, or not.
	my $bool = $doc->exists('//tmpr'); 
	if ($logging == 1) { $logger->info("Inbound line: $_[0]") };
	if ($bool == 1) { 
		$logger->info("Normal energy sample found.");

		# DEFINE CORRECT MySQL TIMESTAMP
		# Find the timestamp in the XML file, but will not use this given the uncertainty of the timestamp being correct. Rather use the NTP sync'ed value on the computer ..
		my $time = $doc->find('//time');
		# Break up the HH:MM:SS format derived from the Currentcost xml
		my ($hours, $minutes, $seconds) = split(/:/, $time);
		my $tm = localtime; 
		#my $timestamp = ($tm->hour . ':' . $tm->min . ':' . $tm->sec);					# No need for this based on current time as this is given by the Currentcost meter, or could replace if need be.. prob better if computers are NTP time sync'ed.
		my $datestamp = ($tm->year+1900 . '-' . (($tm->mon)+1) . '-' . $tm->mday);
		# Using the computers timestamp given this is NTP sync'ed, which most likely is better given the uncertainty on wrong timestamps set on Currentcost itself .. 
		my $dat = DateTime->new( year => $tm->year+1900, month => (($tm->mon)+1), day => $tm->mday, hour => $tm->hour, minute => $tm->min, second => $tm->sec );
		#my $dat = DateTime->new( year => $tm->year+1900, month => (($tm->mon)+1), day => $tm->mday, hour => $hours, minute => $minutes, second => $seconds );
		# Convert to MySQL datetime format, ready for SQL INSERT statement
		my $mysql_datetime_stamp = DateTime::Format::MySQL->format_datetime($dat);

		# DEFINE TEMP (CELCIUS)
		my $temp = $doc->find('//tmpr');

		# DEFINE SENSOR ID
		my $sensor_id = $doc->find('//sensor');

		# DEFINE WATTAGE
		my $wattage = $doc->find('./msg/ch1/watts');

		# Remove leading 0'es from the wattage strings, and assuming that each sensor have only ONE channel - e.g. one WATTAGE item..
		$wattage =~ s/^0+//;
		
		if ($logging ==1) { $logger->info($temp, ", ", $sensor_id, ", ", $mysql_datetime_stamp, ", ", $wattage) };

		my $sensor_old = "SENSORDATA";
		my $sensor_new = $sensor_id;
		my $temp_old = "TEMPDATA";
		my $temp_new = $temp;
		my $unix_epoch_time_old = "TIMESTAMPDATA";
		my $unix_epoch_time_new = time;
		my $timestamp_mysql_old = "MYSQLDATA";
		my $timestamp_mysql_new = "$mysql_datetime_stamp";
		my $watt_old = "WATTDATA";
		my $watt_new = int($wattage); 					# $watt_old is not defined; just using the reference to the value array later..
		my $watt_seconds_old = "WSECONDSDATA";				# this holds the consumed watts since last sample, using UNIX epoch time as the reference
		my $epoch_seconds_diff = 0;

		# Calculate the watt seconds consumed since last sample
		if ($logging == 1) { $logger->info("The local UNIX epoch time is: $unix_epoch_time_new, and the last sample time was: $cc_last_sample_epoch_time") };
		if ($cc_last_sample_epoch_time == 0) {
			$cc_last_sample_epoch_time = $unix_epoch_time_new;
		} else {
			$epoch_seconds_diff = ($unix_epoch_time_new - $cc_last_sample_epoch_time);
			$cc_last_sample_epoch_time = $unix_epoch_time_new;
		}

		if ($logging == 1) { $logger->info("Seconds since last sample: $epoch_seconds_diff") };

		my $watt_seconds_new = $watt_new * $epoch_seconds_diff; 	# This derives the amount of watt_seconds consumed since last sample, and is what we will store as consumed energy.

		if ($logging == 1) { $logger->info("Number of watt_seconds consumption in between now and last sample is $watt_seconds_new") };

		my $shell_command = "curl -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer 892ce0b71d30b2d5cf2c1b10806df382\" -k -d '{ \"event\": { \"payloadData\": { \"SENSOR\": SENSORDATA, \"TEMP\": TEMPDATA, \"TIMESTAMP\": TIMESTAMPDATA, \"TIMESTAMPMYSQL\": \"MYSQLDATA\", \"WATT\": WATTDATA, \"WATTSECONDS\": WSECONDSDATA } } }' -v http://localhost:9763/endpoints/CURRENTCOST_DATA_RECEIVER";

		$shell_command =~ s/$sensor_old/$sensor_new/g;
		$shell_command =~ s/$temp_old/$temp_new/g;
		$shell_command =~ s/$unix_epoch_time_old/$unix_epoch_time_new/g;
		$shell_command =~ s/$timestamp_mysql_old/$timestamp_mysql_new/g;
		$shell_command =~ s/$watt_old/$watt_new/g;
		$shell_command =~ s/$watt_seconds_old/$watt_seconds_new/g;

		print $shell_command, "\n";

		system("$shell_command");
 
		if ($logging == 1) { $logger->info("Committing data to WSO2DAS..") };

		# Build the MySQL INSERT query that has to be executed
		my $query = "insert into CurrentCostDataSamples_MySQL_Raw_Event_Stream (MYSQLTIMESTAMP, TEMP, SENSOR, WATT) 
			values (?, ?, ?, ?) ";

		# prepare your statement for connecting to the database
		my $statement = $_[1]->prepare($query);

		# execute your SQL statement
		if ($logging == 1) { $logger->info("Committing data to MySQL..") };
		$statement->execute($mysql_datetime_stamp, $temp, $sensor_id, $watt_new);

	} else {
		$logger->info("Aggregate energy sample found.");
	}


}

sub ConnectToMySql {
	my $logger = Log::Log4perl->get_logger();

	# MySQL database configuration
	my $db = 'currentcost_v2';
	my $host = 'localhost';
	my $user = 'currentcost_v2';
	my $pass = 'currentcost_v2';
	my $port = '3306';

	# connect to the remote MySQL database that has the Currentcost table(s)
	my $dsn = "DBI:mysql:database=$db;host=$host;port=$port";
	my $dbh  = DBI->connect($dsn, $user ,$pass , { RaiseError => 1 }) or die ( "Couldn't connect to database: " . DBI->errstr );
	if ($logging == 1) { $logger->info("Connected to the MySQL database.") };

	# the value of this connection is returned by the sub-routine
	return $dbh;

}


