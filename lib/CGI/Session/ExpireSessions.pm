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
our $VERSION = '1.00';

# -----------------------------------------------

# Preloaded methods go here.

# -----------------------------------------------

# Encapsulated class data.

{
	my(%_attr_data) =
	(
		_dbh		=> '',
		_delta		=> 2 * 24 * 60 * 60,
		_temp_dir	=> '/tmp',
		_verbose	=> 0,
	);

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
	my($sth)	= $$self{'_dbh'} -> prepare('select * from sessions');

	$sth -> execute();

	my($data, $D, $session_has_expired, @id);

	while ($data = $sth -> fetchrow_hashref() )
	{
		eval $$data{'a_session'};

		$session_has_expired = (time() - $$D{'_SESSION_ATIME'}) >= $$self{'_delta'} ? 1 : 0;

		print STDOUT "Delta time: $$self{'_delta'}. Time lapsed: ", time() - $$D{'_SESSION_ATIME'}, ". Expired?: $session_has_expired. \n" if ($$self{'_verbose'});

		push @id, $$data{'id'} if ($session_has_expired);
	}

	for (@id)
	{
		print STDOUT "Expiring db id: $_. \n" if ($$self{'_verbose'});

		$sth = $$self{'_dbh'} -> prepare('delete from sessions where id = ?');

		$sth -> execute($_);

		$sth -> finish();
	}

	if ($#id < 0)
	{
		print STDOUT "No db ids are due to expire. \n" if ($$self{'_verbose'});
	}

}	# End of expire_db_sessions.

# -----------------------------------------------

sub expire_file_sessions
{
	my($self) = @_;

	opendir(INX, $$self{'_temp_dir'}) || Carp::croak("Can't opendir($$self{'_temp_dir'}): $!");
	my(@file) = grep{/cgisess_[0-9a-f]{32}/} readdir(INX);
	closedir INX;

	my($count) = 0;

	my($file, $D, $session_has_expired);

	for my $file (@file)
	{
		open(INX, $file) || Carp::croak("Can't open($file): $!");
		my(@session) = <INX>;
		close INX;

		eval $session[0];

		$session_has_expired = (time() - $$D{'_SESSION_ATIME'}) >= $$self{'_delta'} ? 1 : 0;

		print STDOUT "Delta time: $$self{'_delta'}. Time lapsed: ", time() - $$D{'_SESSION_ATIME'}, ". Expired?: $session_has_expired. \n" if ($$self{'_verbose'});

		if ($session_has_expired)
		{
			$count++;

			print STDOUT "Expiring file id: $$D{'id'}. \n" if ($$self{'_verbose'});

			unlink $file;
		}
	}

	print STDOUT "No file ids are due to expire. \n" if ( ($count == 0) && $$self{'_verbose'});

}	# End of expire_file_sessions.

# -----------------------------------------------

sub new
{
	my($caller, %arg)	= @_;
	my($caller_is_obj)	= ref($caller);
	my($class)			= $caller_is_obj || $caller;
	my($self)			= bless({}, $class);

	for my $attr_name ($self -> _standard_keys() )
	{
		my($arg_name) = $attr_name =~ /^_(.*)/;

		if (exists($arg{$arg_name}) )
		{
			$$self{$attr_name} = $arg{$arg_name};
		}
		elsif ($caller_is_obj)
		{
			$$self{$attr_name} = $$caller{$attr_name};
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

C<CGI::Session::ExpireSessions> - Expires CGI::Session db-based and file-based sessions

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

It does no more than expire CGI::Session-type sessions which have passed their use-by date.

Expiring a session means deleting that session from the 'sessions' table in the database,
or deleting that session from the temp directory, depending on how you use CGI::Session.

=head1 Distributions

This module is available both as a Unix-style distro (*.tgz) and an
ActiveState-style distro (*.ppd). The latter is shipped in a *.zip file.

See http://savage.net.au/Perl-modules.html for details.

See http://savage.net.au/Perl-modules/html/installing-a-module.html for
help on unpacking and installing each type of distro.

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
