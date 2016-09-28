#!/usr/bin/perl -w

use strict;

use YAML qw( Dump );
use DBI;
use CGI;

################################################################################
# CUSTOMIZABLE VARS
################################################################################

# MySQL - Control
my $mysql_dsn           = 'DBI:mysql:<BD_NAME>:<BD_HOSTNAME_OR_IP>';
my $mysql_username      = '<BD_USER>';
my $mysql_password      = '<BD_PASSWORD>';

# Puppet Dashboard DB
my $dashboard_dsn       = 'DBI:mysql:<DASHBOARD_BD_NAME>:<DASHBOARD_BD_HOSTNAME_OR_IP>';
my $dashboard_username  = '<DASHBOARD_BD_USER>';
my $dashboard_password  = '<DASHBOARD_BD_PASSWORD>';

# TTL - AFTER $interval HOURS WE RESET EVERYTHING.... SEND ALL IN
my $interval            = 24;

################################################################################
# FIXED VARS
################################################################################

use vars qw(%input);
CGI::ReadParse(*input);

my $debug               = 0;
my $remove              = '';

my ($TYPE_ID, $TYPE, $TIME, $UPDATED_AT);
my ($REPORT_ID, $TAGS, $STATUS);
my %class;
my %tags;
my %time;
my %done;
my %report;
my @class;

my $environment = "production";

my %parameters = (
    puppet_server => "<PUPPETMASTER_FQDN>"
);

################################################################################
# ARGUMENTS
################################################################################

$debug                  = 1              if ( defined($input{debug}) );
$remove                 = $input{remove} if ( defined($input{remove}) );


my $hostname = shift || die "No hostname passed";
my $orig_hostname = $hostname;

# ALLOWED DOMAIN VARIATIONS - same ones has in puppet's autosign.conf
if ( ( $hostname =~ /^([^\.]+).test.com$/ ) || ( $hostname =~ /^([^\.]+).test2.com$/ ) ) {
    $hostname = $1;
} else {
    exit;
}

################################################################################
# CONNECT
################################################################################

# CONNECT
my $mysql_dbh = DBI->connect($mysql_dsn, $mysql_username, $mysql_password, { PrintError => 1 }) or die $DBI::errstr;
$mysql_dbh->{mysql_auto_reconnect} = 1;

my $dashboard_dbh = DBI->connect($dashboard_dsn, $dashboard_username, $dashboard_password, { PrintError => 1 }) or die $DBI::errstr;
$dashboard_dbh->{mysql_auto_reconnect} = 1;

################################################################################
# MAIN CODE
################################################################################

if ( $remove ne '' ) {

    my $sql = "delete from reports where reports.host like '$remove';";
    if ( $debug ) {
        print "SQL: $sql\n";
    }

    my $rows_affected = $dashboard_dbh->do($sql);
    if (!$rows_affected) {
        print STDERR "Error: No reports removed\n" if ($debug);
    }

}

my $sql = "select type_id, type, UNIX_TIMESTAMP(PROJECT_servers.updated_at) from PROJECT_servertype, PROJECT_servers where PROJECT_servers.type_id=PROJECT_servertype.id and PROJECT_servers.name='$hostname';";
if ( $debug ) {
    print "SQL: $sql\n";
}

my $data = $mysql_dbh->prepare($sql);
$data->execute;
$data->bind_columns(\$TYPE_ID, \$TYPE, \$UPDATED_AT);

while ( $data->fetch ) {

    my $MODEL   = "";
    my $FILTER  = "";
    my $TIME    = 0;

    my $sql2 = "select PROJECT_puppetmodule.module, PROJECT_puppetmodule.filtro, UNIX_TIMESTAMP(PROJECT_puppetmodule.updated_at) from PROJECT_puppetmodule, PROJECT_puppetclass_modules, PROJECT_puppetclass, PROJECT_puppetclass_servertype where PROJECT_puppetmodule.id=PROJECT_puppetclass_modules.puppetmodule_id AND PROJECT_puppetclass_modules.puppetclass_id=PROJECT_puppetclass.id AND PROJECT_puppetclass.id=PROJECT_puppetclass_servertype.puppetclass_id AND PROJECT_puppetclass_servertype.servertype_id=$TYPE_ID AND ( PROJECT_puppetmodule.expire_at>NOW() OR PROJECT_puppetmodule.expire_at is NULL );";
    if ( $debug ) {
        print "SQL: $sql2\n";
    }
    my $data2 = $mysql_dbh->prepare($sql2);
    $data2->execute;
    $data2->bind_columns(\$MODEL, \$FILTER, \$TIME);
    while ( $data2->fetch ) {

        my %include;
        my %exclude;

        $time{$MODEL} = $TIME;

        if ( defined($FILTER) && ( $FILTER ne '' ) ) {
            $MODEL  =~ s/ //g;
            $FILTER =~ s/ //g;
            $FILTER =~ s/\r//g;
            $FILTER =~ s/\n//g;
            if ( $FILTER =~ /^!/ ) {
                $FILTER = '.*,' . $FILTER;
		    }
            my @hosts = split ',', $FILTER;
            foreach my $host (@hosts) {
                my $neg = ( $host =~ /^!/ );
                $host =~ s/^!//;
                if ( $hostname =~ /$host/i ) {

                    if ( $neg ) {
                        $exclude{$MODEL} = 1;
                    } else {
                        $include{$MODEL} = 1;
                    }
                }
            }
            foreach my $model (keys %include) {
                if ( ! exists $exclude{$model} ) {
                    $class{$model} = 1;
                }
            }

        } else {
            $class{$MODEL} = 1;
        }
    }
}


$sql = "select id from reports where reports.host like '$orig_hostname%' AND time > DATE_SUB(NOW(), INTERVAL $interval HOUR) order by id asc;";
if ( $debug ) {
    print "SQL: $sql\n";
}


$data = $dashboard_dbh->prepare($sql);
$data->execute;
$data->bind_columns(\$REPORT_ID);

while ( $data->fetch ) {

    $sql = "select tags, UNIX_TIMESTAMP(time), status from resource_statuses WHERE report_id=$REPORT_ID;";
    if ( $debug ) {
            print "SQL: $sql\n";
    }

    my $data2 = $dashboard_dbh->prepare($sql);
    $data2->execute;
    $data2->bind_columns(\$TAGS, \$TIME, \$STATUS);

    while ( $data2->fetch ) {
        my $model;

        if ( $TAGS =~ /(\w+::[^\s]+)/ ) {
            $model = $1;
        } else {
            next;
        }

        # Skip model if already UPDATED
        if ( exists $time{$model} ) {
            if ( $TIME > $time{$model} ) {
                if ( $STATUS =~ /changed/ ) {

                    if ( exists($report{$model}) && ( $report{$model} ne $REPORT_ID ) ) {
                        if ( ! $done{$model} ) {
                            print "1: $model:\t" . $TIME . " > " . $time{$model} . "\t" . $STATUS . "\t1\n" if ($debug);
                            $done{$model} = 1;
                        }
                    } else {
                        print "2: $model:\t" . $TIME . " > " . $time{$model} . "\t" . $STATUS . "\t1\n" if ($debug);
                        $done{$model} = 1;
                    }
                } else {
                    print "3: $model:\t" . $TIME . " > " . $time{$model} . "\t" . $STATUS . "\t0\n" if ($debug);
                    $done{$model} = 0;
                }
            } else {
                print "4: $model:\t" . $TIME . " > " . $time{$model} . "\t" . $STATUS . "\t0\n" if ($debug);
                $done{$model} = 0;
            }
        } else {
            print "5: $model:\t" . $TIME . " > " . $time{$model} . "\t" . $STATUS . "\t0\n" if ($debug);
            $done{$model} = 0;
        }

    }
    die $data2->errstr if $data->err;
}

foreach my $model (sort keys %done) {
    print $model .  " - " . $done{$model} . "\n" if ($debug);
    if ( ( exists $done{$model} ) && ( $done{$model} ) ) {
        delete $class{$model};
    }
}

@class = sort keys %class;


die $data->errstr if $data->err;
$mysql_dbh->disconnect;

$dashboard_dbh->disconnect;

print Dump( {
    classes => \@class,
    environment => $environment,
    parameters => \%parameters,
} );
