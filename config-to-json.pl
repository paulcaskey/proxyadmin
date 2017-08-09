#!/usr/bin/env perl

# Paul Caskey, July 2017
# Distributed as open source under GNU GPL v3.0
# https://github.com/paulcaskey/proxyadmin/
#
# Starting point of a bigger "proxyadmin" project to help administer ProxySQL.
#
# This script requires the DBI, DBD::Mysql, and JSON perl modules. It talks
# to your ProxySQL server on whatever IP and port you define below or pass
# in with environment variables as shown.
#
# This was developed against proxysql v1.4.1.  It may error out on previous
# proxysql versions if it hits a table that does not exist.  However, it
# makes no presumption on which columns are in each table, so it's pretty
# flexible.  It's also stubbed out to let you specify columns if you wish.
# (See sub "fetchTbl" below.)
#
# In the JSON output, note that it prints the key-value pairs from hashes
# out of order.  You could probably dig into the JSON module to find options
# to change that if you wish.

########################  SETUP  #############################

my $ADMIN_HOST = defined $ENV{"ADMIN_HOST"} ? $ENV{"ADMIN_HOST"} : "127.0.0.1";
my $ADMIN_PORT = defined $ENV{"ADMIN_PORT"} ? $ENV{"ADMIN_PORT"} : "6032";
my $ADMIN_USER = defined $ENV{"ADMIN_USER"} ? $ENV{"ADMIN_USER"} : "admin";
my $ADMIN_PASS = defined $ENV{"ADMIN_PASS"} ? $ENV{"ADMIN_PASS"} : "admin";

use DBI;
my $dsn = "DBI:mysql:database=main;host=$ADMIN_HOST;port=$ADMIN_PORT";
my $dbh = DBI->connect($dsn, $ADMIN_USER, $ADMIN_PASS) or die;

use JSON;
my $json = JSON->new;  # ->allow_nonref;

######################## SUBROUTINES ########################

sub fetchTbl {
    my $table   = shift || return 0;
    my $columns = @_ ? shift : "*";

    my $sth = $dbh->prepare("SELECT $columns FROM $table") || return 0;
    my $res = $sth->execute() || return 0;

    # Label every key-value pair, but it ends up out of order ...
    return $sth->fetchall_arrayref( {} );

    # ... OR use ordered arrays, but then you lose column names.
#    return $sth->fetchall_arrayref();
}

################ DATA STRUCTURE DECLARATIONS ################

my $proxyconf = {};

# The 'ondisk' part isn't grabbed yet. Might take a connection via
# sqlite3 to really get it all.  Defined here for completeness.

$proxyconf->{'ondisk'} = {};                    # TIER 1
$proxyconf->{'ondisk'}->{'mysql'} = {};
$proxyconf->{'ondisk'}->{'stats'} = {};
$proxyconf->{'ondisk'}->{'config'} = {};
$proxyconf->{'ondisk'}->{'sched'} = {};

$proxyconf->{'memory'} = {};                    # TIER 2
$proxyconf->{'memory'}->{'mysql'} = {};
$proxyconf->{'memory'}->{'stats'} = {};
$proxyconf->{'memory'}->{'config'} = {};
$proxyconf->{'memory'}->{'sched'} = {};

$proxyconf->{'runtime'} = {};                   # TIER 3
$proxyconf->{'runtime'}->{'mysql'} = {};
$proxyconf->{'runtime'}->{'stats'} = {};
$proxyconf->{'runtime'}->{'config'} = {};
$proxyconf->{'runtime'}->{'sched'} = {};

################ SLURP IN SOME LIVE ADMIN DATA ################

$ref = $proxyconf->{'memory'}->{'mysql'};
#          mysql_collations
foreach $table (qw/
         mysql_servers
         mysql_users
         mysql_query_rules
         mysql_replication_hostgroups
         mysql_group_replication_hostgroups
/) {
    $ref->{$table} = fetchTbl($table);
}


$ref = $proxyconf->{'memory'}->{'stats'};
foreach $table (qw/stats_memory_metrics
                   stats_mysql_commands_counters
                   stats_mysql_connection_pool
                   stats_mysql_global
                   stats_mysql_processlist
                   stats_mysql_query_digest
                   stats_mysql_query_rules
                   stats_mysql_users/) {
    $ref->{$table} = fetchTbl($table);
}

$ref = $proxyconf->{'memory'}->{'config'};
foreach $table (qw/global_variables/) {
    $ref->{$table} = fetchTbl("$table ORDER BY variable_name");
}

$ref = $proxyconf->{'runtime'}->{'config'};
foreach $table (qw/runtime_global_variables/) {
    $ref->{$table} = fetchTbl("$table ORDER BY variable_name");
}

$ref = $proxyconf->{'memory'}->{'sched'};
foreach $table (qw/scheduler/) {
    $ref->{$table} = fetchTbl("$table ORDER BY id");
}

$ref = $proxyconf->{'runtime'}->{'sched'};
foreach $table (qw/runtime_scheduler/) {
    $ref->{$table} = fetchTbl("$table ORDER BY id");
}

$ref = $proxyconf->{'runtime'}->{'mysql'};
foreach $table (qw/runtime_mysql_servers
                   runtime_mysql_users
                   runtime_mysql_query_rules
                   runtime_mysql_group_replication_hostgroups
                   runtime_mysql_query_rules
                   runtime_mysql_replication_hostgroups
/) {
    $ref->{$table} = fetchTbl("$table");
}

################ PRINT OUT WHATEVER TREE YOU WANT ################

# Examples of smaller pieces
# print $json->pretty->encode($proxyconf->{'memory'}->{'mysql'});
# print $json->pretty->encode($proxyconf->{'memory'}->{'stats'});

# The main part you probably want
# print $json->encode($proxyconf->{'memory'});
print $json->pretty->encode($proxyconf->{'memory'});

# Everything -- but nothing really pulled from "ondisk" yet.
# print $json->pretty->encode($proxyconf);
