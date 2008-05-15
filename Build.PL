use Module::Build;

Module::Build -> new
(
	module_name		=> 'CGI::Session::ExpireSessions',
	license			=> 'artistic',
	dist_author		=> 'Ron Savage <ron@savage.net.au>',
	build_requires	=>
	{
		Test::More	=> 0,
		Test::Pod	=> 0,
	},
	requires		=>
	{
		Carp			=> 0,
		CGI::Session	=> 4.14,
		File::Spec		=> 0,
	},
) -> create_build_script();