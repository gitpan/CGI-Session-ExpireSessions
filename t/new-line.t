#!/usr/bin/perl

use strict;
use diagnostics;

BEGIN
{
	use Test::More;
	plan(tests => 5);
	use_ok('CGI::Session');
	use_ok('CGI::Session::ExpireSessions');
};

# Create a block so $s goes out of scope before we try to access the session.
# Without the {}, CGI::Session::ExpireSessions does not see this session,
# although it will see sessions created by previous runs of this program.

{
	my($s) = new CGI::Session(undef, undef, {Directory => 't'} );

	ok($s);

	$s -> expire(1);

	ok($s -> id);

	$s -> param(purpose => "Test new-line within session data. Works with CGI::Session::ExpireSessions V 1.06\n");

	ok($s -> param('purpose') );
}

# Sleep 2 hoping than at least 1 whole second has elapsed before
# we try to access the session. Sleep is not precise...

sleep(2);

CGI::Session::ExpireSessions -> new(delta => 0, temp_dir => 't') -> expire_file_sessions();
