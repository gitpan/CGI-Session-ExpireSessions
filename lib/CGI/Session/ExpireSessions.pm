package CGI::Session::ExpireSessions;

# Name:
#	CGI::Session::ExpireSessions.
#
# Documentation:
#	POD-style documentation is at the end. Extract it with pod2html.*.
#
# Reference:
#	Object Oriented Perl
#	Damian Conway
#	Manning
#	1-884777-79-1
#	P 114
#
# Note:
#	o Tab = 4 spaces || die.
#
# Author:
#	Ron Savage <ron@savage.net.au>
#	Home page: http://savage.net.au/index.html
#
# Licence:
#	Australian copyright (c) 2004 Ron Savage.
#
#	All Programs of mine are 'OSI Certified Open Source Software';
#	you can redistribute them and/or modify them under the terms of
#	The Artistic License, a copy of which is available at:
#	http://www.opensource.org/licenses/index.html

use strict;
use warnings;

require 5.005_62;

require Exporter;

use Carp;
use File::Spec;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use CGI::Session::ExpireSessions ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);
our $VERSION = '1.05';

# -----------------------------------------------

# Preloaded methods go here.

# -----------------------------------------------

# Encapsulated class data.

{
	my(%_attr_data) =
	(
		_dbh		=> '',
		_delta		=> 2 * 24 * 60 * 60, # Seconds.
		_table_name	=> 'sessions',
		_temp_dir	=> '/tmp',
		_verbose	=> 0,
	);

	sub _check_expiry
	{
		my($self, $D)	= @_;
		my($expired)	= 0;
		my($time)		= time();

		if ( ($time - $$D{'_SESSION_ATIME'}) >= $$self{'_delta'})
		{
			$expired = 1;

			print STDOUT "Delta time: $$self{'_delta'}. Time elapsed: ", $time - $$D{'_SESSION_ATIME'}, ". Expired?: $expired. \n" if ($$self{'_verbose'});
		}

		if ($$D{'_SESSION_ETIME'} && ! $expired)
		{
			$expired = 1 if ($time >= ($$D{'_SESSION_ATIME'} + $$D{'_SESSION_ETIME'}) );

			print STDOUT "Last access time: $$D{'_SESSION_ATIME'}. Expiration time: $$D{'_SESSION_ETIME'}. Time elapsed: ", $time - $$D{'_SESSION_ATIME'}, ". Expired?: $expired. \n" if ($$self{'_verbose'});
		}

		$expired;
	}

	sub _default_for
	{
		my($self, $attr_name) = @_;

		$_attr_data{$attr_name};
	}

	sub _standard_keys
	{
		keys %_attr_data;
	}

}	# End of encapsulated class data.

# -----------------------------------------------

sub expire_db_sessions
{
	my($self)	= @_;
	my($sth)	= $$self{'_dbh'} -> prepare("select * from $$self{'_table_name'}");

	$sth -> execute();

	my($data, $D, @id, $untainted_data);

	while ($data = $sth -> fetchrow_hashref() )
	{
		# Untaint the data the brute force way.

		($untainted_data) = $$data{'a_session'} =~ /(.*)/;

		eval $untainted_data;

		push @id, $$data{'id'} if ($self -> _check_expiry($D) );
	}

	for (@id)
	{
		print STDOUT "Expiring db id: $_. \n" if ($$self{'_verbose'});

		$sth = $$self{'_dbh'} -> prepare("delete from $$self{'_table_name'} where id = ?");

		$sth -> execute($_);

		$sth -> finish();
	}

	if ( ($#id < 0) && $$self{'_verbose'})
	{
		print STDOUT "No db ids are due to expire. \n";
	}

}	# End of expire_db_sessions.

# -----------------------------------------------

sub expire_file_sessions
{
	my($self) = @_;

	opendir(INX, $$self{'_temp_dir'}) || Carp::croak("Can't opendir($$self{'_temp_dir'}): $!");
	my(@file) = map{File::Spec -> catfile($$self{'_temp_dir'}, $_)} grep{/cgisess_[0-9a-f]{32}/} readdir(INX);
	closedir INX;

	my($count)	= 0;
	my($time)	= time();

	my($file, @stat, $D);

	for my $file (@file)
	{
		@stat = stat($file);

		# Delete old, tiny files.

		if ( ( ($time - $stat[8]) >= $$self{'_delta'}) && ($stat[7] <= 5) )
		{
			$count++;

			print STDOUT "Delta time: $$self{'_delta'}. Size: $stat[7] bytes. Time elapsed: ", $time - $stat[8], ". Expired?: 1. \n" if ($$self{'_verbose'});

			unlink $file;

			next;
		}

		# Ignore new, tiny files.

		next if ($stat[7] <= 5);

		open(INX, $file) || Carp::croak("Can't open($file): $!");
		my(@session) = <INX>;
		close INX;

		# Pod/perlfunc.html#item_eval
		# This does not work:
		# eval{no warnings 'all'; $session[0]};

		eval $session[0];

		if ($@)
		{
			print STDOUT "Unable to parse contents of file: $file. \n" if ($$self{'_verbose'});

			next;
		}

		if ($self -> _check_expiry($D) )
		{
			$count++;

			print STDOUT "Expiring file id: $$D{'_SESSION_ID'}. \n" if ($$self{'_verbose'});

			unlink $file;
		}
	}

	print STDOUT "No file ids are due to expire. \n" if ( ($count == 0) && $$self{'_verbose'});

}	# End of expire_file_sessions.

# -----------------------------------------------

sub new
{
	my($class, %arg)	= @_;
	my($self)			= bless({}, $class);

	for my $attr_name ($self -> _standard_keys() )
	{
		my($arg_name) = $attr_name =~ /^_(.*)/;

		if (exists($arg{$arg_name}) )
		{
			$$self{$attr_name} = $arg{$arg_name};
		}
		else
		{
			$$self{$attr_name} = $self -> _default_for($attr_name);
		}
	}

	Carp::croak(__PACKAGE__ . ". You must specify a value for one of the parameters 'dbh' or 'temp_dir'") if (! ($$self{'_dbh'} || $$self{'_temp_dir'}) );

	return $self;

}	# End of new.

# -----------------------------------------------

1;

__END__

=head1 NAME

C<CGI::Session::ExpireSessions> - Delete expired CGI::Session db-based and file-based sessions

=head1 Synopsis

	#!/usr/bin/perl

	use strict;
	use warnings;

	use CGI::Session::ExpireSessions;
	use DBI;

	# -----------------------------------------------

	my($dbh) = DBI -> connect
	(
	  'DBI:mysql:aussi:127.0.0.1',
	  'root',
	  'pass',
	  {
	    AutoCommit         => 1,
	    PrintError         => 0,
	    RaiseError         => 1,
	    ShowErrorStatement => 1,
	  }
	);

	CGI::Session::ExpireSessions -> new(dbh => $dbh, verbose => 1) -> expire_db_sessions();
	CGI::Session::ExpireSessions -> new(temp_dir => '/tmp', verbose => 1) -> expire_file_sessions();

=head1 Description

C<CGI::Session::ExpireSessions> is a pure Perl module.

It deletes CGI::Session-type sessions which have passed their use-by date.

It works with CGI::Session-type sessions in a database or in disk files, but does not work with
CGI::Session::PureSQL-type sessions.

Sessions can be expired under one of three conditions:

=over 4

=item You deem the session to be expired as of now

You want the session to be expired and hence deleted now because it's last access time is longer ago than the
time you specify in the call to new, using the delta parameter.

That is, delete the session because the time span, between the last access time and now, is greater than delta.

In other words, force sessions to expire.

The module has always used this condition to delete sessions.

=item The session has already expired

This condition is new as of V 1.02.

You want the session to be deleted now because it has already expired.

That is, you want this module to delete the session, rather than getting CGI::Session to delete it, when
CGI::Session would delete the session automatically if you used CGI::Session to retrieve the session.

Note: This condition assumes the session's expiration time is defined (it does not have to be).

=item The file size is <= 5 bytes and was accessed more than 'delta' seconds ago

This condition is new as of V 1.03.

See below for how to provide a value of delta to the constructor.

CGI::Session sometimes creates a file of size 0 bytes, so this test checks for such files,
and deletes them if they are old enough.

=back

Sessions are deleted if any of these conditions is true.

Sessions are deleted from the 'sessions' table in the database, or from the temp directory,
depending on how you use CGI::Session.

=head1 Distributions

This module is available both as a Unix-style distro (*.tgz) and an
ActiveState-style distro (*.ppd). The latter is shipped in a *.zip file.

See http://savage.net.au/Perl-modules.html for details.

See http://savage.net.au/Perl-modules/html/installing-a-module.html for
help on unpacking and installing each type of distro.

=head1 Security

For file-based sessions, C<CGI::Session::ExpireSessions> parses the first line of the
file, using eval{}, in an attempt to determine the access and expiration times recorded
within the file.

So, if you are uneasy about the security implication of this, don't use this module.

=head1 Constructor and initialization

new(...) returns a C<CGI::Session::ExpireSessions> object.

This is the class's contructor.

Usage: CGI::Session::ExpireSessions -> new().

This method takes a set of parameters. Only some of these parameters are mandatory.

For each parameter you wish to use, call new as new(param_1 => value_1, ...).

=over 4

=item dbh

This is a database handle for the database containing the table 'sessions'.

Either this parameter is mandatory, or the temp_dir parameter is mandatory.

=item delta

This is the number of seconds after the last access to the session, which determines
whether or not the session will be expired.

The default value is 2 * 24 * 60 * 60, which is the number of seconds in 2 days.

Sessions which were last accessed more than 2 days ago are expired.

This parameter is optional.

=item table_name

This is the name of the database table used to hold the sessions.

The default value is 'sessions'.

This parameter is optional.

=item temp_dir

This is the name of the temp directory where you store CGI::Session-type session files.

The default value is '/tmp'.

Either this parameter is mandatory, or the dbh parameter is mandatory.

=item verbose

This is a integer, 0 or 1, which - when set to 1 - causes progress messages to be
written to STDOUT.

The default value is 0.

This parameter is optional.

=back

=head1 Method: expire_db_sessions()

Returns nothing.

This method uses the dbh parameter passed to C<new()> to delete database-type sessions.

=head1 Method: expire_file_sessions()

Returns nothing.

This method uses the temp_dir parameter passed to C<new()> to delete file-type sessions.

=head1 Example code

See the examples/ directory in the distro.

There is 1 demo file: expire-sessions.pl.

=head1 Related Modules

=over 4

=item CGI::Session

=back

=head1 Required Modules

=over 4

=item Carp

=back

=head1 Author

C<CGI::Session::ExpireSessions> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2004.

Home page: http://savage.net.au/index.html

=head1 Copyright

Australian copyright (c) 2004, Ron Savage. All rights reserved.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
