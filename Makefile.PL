use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
	($] ge '5.005') ?
	(
		'AUTHOR'	=> 'Ron Savage (ron@savage.net.au)',
		'ABSTRACT'	=> 'Delete expired CGI::Session db-based and file-based sessions',
    ) : (),
	clean			=>
	{
		FILES		=> 'blib/* Makefile MANIFEST CGI-Session-ExpireSessions-*'
	},
	dist			=>
	{
		COMPRESS	=> 'gzip',
		SUFFIX		=> 'gz'
	},
	DISTNAME		=> 'CGI-Session-ExpireSessions',
	NAME			=> 'CGI::Session::ExpireSessions',
	PL_FILES		=> {},
	PREREQ_PM		=>
	{
		Carp		=> 0,
		File::Spec	=> 0,
		Test::More	=> 0,
		Test::Pod	=> 0,
	},
	VERSION_FROM	=> 'lib/CGI/Session/ExpireSessions.pm',
);
