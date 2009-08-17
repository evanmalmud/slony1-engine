#!/usr/bin/perl -w
# $Id: bulk_load_for_slony.pl,v 1.2 2009-08-17 17:25:50 devrim Exp $

# Bulk loader for slony-managed table.
# This script takes one argument: the name of a config file.
# The config file MUST include all the configuration data needed.
# If it does not, the script will bail with a suitably 
# carpy message.

# andrew@ca.afilias.info 2007-01-04

=pod 

=head1 bulk_load_for_slony.pl

=head2 Syntax

B<bulk_load_for_slony.pl> I<configfile>

=head2 DANGER WILL ROBINSON

This script performs a somewhat-dangerous bulk load of a PostgreSQL
table that is managed by Slony-I.  If your table I<is not> managed by
Slony, I<do not use this script>.  This is intended to make it
possible for people who have a very good idea of what their database
is already doing to perform bulk loads.  It does not try to ascertain
that you are sure of what you are doing; neither does it make sure
things will work as you expect.  It may commit data that breaks your
tables.  If you use it on a table that is under active use by your
application I<it will certainly break things>, and not in a way you can
roll back.  Please go away now, and use safer methods, if your data is
anything but trivially-regenerated garbage that you do not care about.

=head2 Overview

This script attempts to perform a bulk load of a specified file, which
must exist in the same location on every database node specified, into
a Slony database cluster of machines.  If something goes wrong as far
as it can tell, it complains and exits, leaving your databases in an
inconsistent state.  It is intended to be used I<only> on tables where
no application is dependent on the table, as a bootstrap mechanism.

The file to be loaded should be in the format similar to that
generated by pg_dump:

=over 4

=item -

Every field is specified, including "\N" for NULLs.

=item -

Fields are separated by one tab character

=item -

The COPY is terminated by the end-of-data character, "\."  While the
end of data character is not actually necessary because this tool
currently only works for one table, the restriction is here for later,
in case this tool is altered to support multiple tables.

=back

See the PostgreSQL manual section on COPY for more information about
this file.  In principle, you could include WITH arguments in your
COPY file, but such behaviour has not been tested or allowed for.

=head2 Configuration file

All configuration of the script is done using a configuration file.
The name of that file is a mandatory argument to the script.  The file
is set up similarly to the configuration file for the altperl Slony
tools.  This file is parsed directly by Perl.

=over 4 

=item add_node() stanzas

For each node in the cluster, you should have one add_node entry.
Each add_node entry includes several items enclosed in parentheses and
terminated with a semi-colon, like this:

   add_node (
       some_argument  => 'foo',
`      other_argument => 'bar');

The available arguments are as follows.  The add_node stanzas from
your slon_tools.conf file, if you have one, should work here, except
that the parameters parent and noforward have no effect.  Note that
this script nevertheless does not depend on the existence of
slon-tools.pm.

=Over 8

=item node

A numeric identifier of the node.  This must be unique for each node.
It need not be the same number as the node numbers that Slony uses,
although using it that way will certainly make maintenance less
confusing.  This number is not actually used by the script, in any case.

=item host

The name of the host from which the database for this node is served.
It must be specified.  Remember that 'localhost' refers to the machine
from which the script runs.  This value must be enclosed in single
quotes (').

=item dbname

The name of the database for this node.  The value must be enclosed in
single quotes.  This value is required.

=item port

This is the port the database is listening on.  If not specified, it
defaults to 5432.

=item user

This is the database user that will perform the work.  This user
should be the slony administration user.  If not specified, it
defaults to postgres.

=item password

This is the password for the user above.  The use of this field is not
recommended.  Use the .pgpass facility instead.

=back

I<NOTE WELL:> There is effectively no way to make sure that you have
specified all the actual nodes in your cluster.  The script will check
to make sure that the number of specified cluster members is
equivalent to the count() of sl_node, but that's as much as it can
do.  This script is therefore dangerous, in that it is entirely
possible to send your copy of data to a machine that does not exist.
This may not be detected until you have an unrecoverable condition
(i.e. data on one node, not yet loaded on another).  I<Check your
configuration very carefully.>

=item $CLUSTERNAME

This is the clustername for Slony.  It is the same as Slony's schema
name, minus the "_" at the beginning.

=item $FILELOC

This is the full path to the filename.  The filename must be the same
on every machine in the cluster, which is reasonable since the file
has to be the same on every machine.  The script I<does not> check to
make sure that the files are the same on every machine: you have to
make sure of that in advance yourself.  If the files are not the same,
the tables will be bulk loaded with different data.

The file (and its entire path) must be readable by the user running
the back end, in the same way that every COPY file must be.  This item
is mandatory.

=item $SCHEMANAME

This is the schema name of the table into which data is to be copied.
If it is not specified, or if it is empty, the value defaults to public.

=item $TABLENAME

This is the table into which data is to be copied.  This item is mandatory.

=item @COLUMNLIST

This is the list of the columns of the table into which the data is to
be copied.  I<These must be in the same order as your data in the
file.>  If the column list is unspecified, no column list will be used
in the COPY command sent to the back end.

=back

=head2 Operation

The script must be invoked from a machine that has access to every
PostgreSQL node listed in the configuration file.  On invocation, it
parses the configuration file.  It builds a COPY statement to load the
bulk file into the target table, and then connects to each node in
turn.  It checks to make sure that there are as many nodes listed in
sl_node as are configured in its configuration file.  It learns the
table identifier for Slony by querying the cluster's sl_table table,
then removes that table from replication by calling the
altertablerestore() function.  It then runs its COPY query.  It checks
the return value of the copy query.  If that returns OK, then it
retores the table to replication using the altertableforreplication()
function.  

The script proceeds to perform the same operations for every table
listed in the configuration file.

If any step fails, the script immediately exits.  It attempts to
detail what it was doing when it failed, but operators are advised to
perform detailed subsequent checks to ensure the report is correct and
does not conceal some other problem.

Note that the script returns the first table to replicating status
before all the other nodes have been loaded.  It is recommended that
the origin node be listed last among the cluster members, but such an
approach does not in any case ensure no data loss.

I<Note that the above description means you can break your replicas.>
The script makes no effort whatever to leave your replicas in a usable
state.  In particular, if any failure is detected, you I<MUST> check
all nodes and, possibly, recover manually.  I<TO REPEAT:> Do not use
this script on a table in which already-existing data resides if you
cannot afford to lose that data.  

=head2 Prerequisites

This script depends on the Pg Perl module, available from CPAN.

=head2 Author's address

Andrew Sullivan
Afilias
204-4141 Yonge Street
Toronto, ON
M2P 2A8
<andrew@ca.afilias.info>

=head2 BUGS

It might be argued that the three steps of removing from replication,
COPYing data, and re-adding to replication should be performed in a
single transaction, to avoid leaving a table in a broken state.  The
author considers the current approach a feature rather than a bug,
because the table replication will be broken in the event of errors,
so the operator will be unable accidentally to re-enable replication
when tables have different data.

=head2 COPYRIGHT

Copyright (c) 2007-2009, PostgreSQL Global Development Group

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose, without fee, and without a written
agreement is hereby granted, provided that the above copyright notice
and this paragraph and the following two paragraphs appear in all
copies.

THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use vars qw ( @NODES @HOST @DBNAME @USER @PORT
            @PASSWORD @SSLMODE @DSN @connstr $CLUSTERNAME $FILELOC
            $SCHEMANAME $TABLENAME @COLUMNLIST);
use Pg;
use strict;

my $configfile = $ARGV[0] or
  die ("You must specify a configuration file.\n");

#parse the config file
require $configfile;

my $slonyschem = "_" . $CLUSTERNAME;

my $schema;
if (defined($SCHEMANAME)) {
  $schema = $SCHEMANAME;
} else {
  $schema = "public";
}

my $columns;
if (defined(@COLUMNLIST)) {
  my $i = 0;
  foreach my $column (@COLUMNLIST) {
    if ($i == 0) {
      $columns = "(" . $column;
      $i++;
    } else {
      $columns = $columns . ", " . $column;
      $i++;
    }
  }
  $columns = $columns . ")";
}

# We have enough now to build the COPY statement.

my $copystmt = "COPY " . $schema . "." . $TABLENAME;
$copystmt = $copystmt . " " . $columns if defined ($columns);
$copystmt = $copystmt . " FROM '" . $FILELOC . "';";

# now we connect to each host in turn, unhook our table from
# replication, bulk load the table, and then re-enable replication
# In the event anything indicates it didn't work, we fail.

# we want to know how many nodes we have to do
my $numnodes = @connstr;
foreach my $connopt (@connstr) {
  my $conn = Pg::connectdb($connopt);
  my $status_conn = $conn->status;

  if ($status_conn ne PGRES_CONNECTION_OK) {
    print "No connection to database.\n";
    print "Status: $status_conn\n";
    print $conn->errorMessage;
    die("Can't proceed on connection $connopt\n");
  }

  # get the table id for the table in question.

  my $qstring = "SELECT tab_id FROM " . $slonyschem;
  $qstring = $qstring . ".sl_table WHERE tab_relname = '";
  $qstring = $qstring . $TABLENAME;
  $qstring = $qstring . "' AND tab_nspname = '";
  $qstring = $qstring . $schema . "'";

  my $get_tab_id = $conn->exec($qstring);
  unless (($get_tab_id->resultStatus) eq PGRES_TUPLES_OK) {
    print "PANIC: getting table id failed: $get_tab_id->resultStatus\n";
    die "Cound not handle replication info for $connopt\n";
  }
  # check to make sure we have the right number of connections
  my $tab_id = $get_tab_id->getvalue(0,0);
  $qstring = "SELECT count(1) FROM " . $slonyschem;
  $qstring = $qstring . ".sl_node";
  my $slnodes = (($conn->exec($qstring))->getvalue(0,0));
  unless ($slnodes == $numnodes) {
    print "Your config has $numnodes nodes\n";
    print "Slony thinks it has $slnodes nodes\n";
    die "Mismatch!\n";
  }
  # now that we have the table id, disable it in replication
  $qstring = "SELECT " . $slonyschem;
  $qstring = $qstring . ".altertablerestore(" . $tab_id . ")";
  my $replic_change = $conn->exec($qstring);
  unless (($replic_change->resultStatus)  eq PGRES_TUPLES_OK) {
    print "PANIC: failed attempting to disable replication\n";
    printf ("Result is %s\n",($replic_change->resultStatus));
    die "Could not disable replication on connection $connopt\n";
  }
  # perform the bulk load
  my $bulk_load = $conn->exec($copystmt);
  my $errstat = ($bulk_load->resultStatus);
  unless ($errstat eq PGRES_COMMAND_OK) {
    print "ERROR in bulk load: $errstat\n";
    die "Could not bulk load for $connopt\n";
  }
  #restore the replication
  $qstring = "SELECT " . $slonyschem;
  $qstring = $qstring . ".altertableforreplication(" . $tab_id . ")";
  $replic_change = $conn->exec($qstring);
  unless (($replic_change->resultStatus)  eq PGRES_TUPLES_OK) {
    print "PANIC: failed attempting to enable replication\n";
    die "Could not enable replication on connection $connopt\n";
  }

  # if that all worked, we can do the next one.
}

print "All nodes processed.\n";


sub add_node {
# mostly lifted from the "altperl" tools in the slony source distribution.   
# Author: Christopher Browne
# Copyright 2004-2009 Afilias Canada

# yes, some of this could be removed, but I don't have time to do it now.

  my %PARAMS = (host=> undef,
                dbname => 'template1',
                port => 5432,
                user => 'postgres',
                node => undef,
                password => undef,
                sslmode => undef
               );
  my $K;
  while ($K= shift) {
    $PARAMS{$K} = shift;
  }
  die ("I need a node number") unless $PARAMS{'node'};
  my $node = $PARAMS{'node'};
  push @NODES, $node;
  my $loginstr;
  my $host = $PARAMS{'host'};
  if ($host) {
    $loginstr .= "host=$host";
    $HOST[$node] = $host;
  } else {
    die("I need a host name") unless $PARAMS{'host'};
  }
  my $dbname = $PARAMS{'dbname'};
  if ($dbname) {
    $loginstr .= " dbname=$dbname";
    $DBNAME[$node] = $dbname;
  }
  my $user=$PARAMS{'user'};
  $loginstr .= " user=$user";
  $USER[$node]= $user;

  my $port = $PARAMS{'port'};
  if ($port) {
    $loginstr .= " port=$port";
    $PORT[$node] = $port;  } else {
    die ("I need a port number");
  }
  my $password = $PARAMS{'password'};
  if ($password) {
    $loginstr .= " password=$password";
    $PASSWORD[$node] = $password;
  }
  my $sslmode = $PARAMS{'sslmode'};
  if ($sslmode) {
    $loginstr .= " sslmode=$sslmode";
    $SSLMODE[$node] = $sslmode;
  }
  $DSN[$node] = $loginstr;
push @connstr, $loginstr;
}
