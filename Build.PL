use Module::Build;

Module::Build -> new
(
	module_name	=> 'CGI::Session::ExpireSessions',
	license		=> 'artistic',
	dist_author	=> 'Ron Savage <ron@savage.net.au>',
	requires	=>
	{
		Carp			=> 0,
	},
) -> create_build_script();