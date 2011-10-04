use strict;
use warnings;
use Module::Build;

{ # define a handy rscan_dir function
    my $manifest_skip = qr/(?!)/; # this regex always fails 
    if (open my $fh, '<', 'MANIFEST.SKIP')
    {
        # map /.*/ chomps newlines, since . doesn't match EOLs
        $manifest_skip = join '|', map /(.*)/, <$fh>;
        close $fh;
        $manifest_skip = qr/$manifest_skip/;
    }

    sub rscan_dir
    {
        grep !/$manifest_skip/, @{ Module::Build->rscan_dir(@_) };
    }
}

my $builder = Module::Build->new
    (module_name         => 'Text::Glob::Expand',
     license             => 'artistic',
     dist_author         => 'Nick Stokoe <npw@cpan.org>',
     dist_version_from   => 'lib/Text/Glob/Expand.pm',
     dist_abstract       => 'permute and expand glob-like text patterns',
     create_readme       => 1,
     create_makefile_pl  => 'traditional',
     meta_merge          =>
     {
         resources =>
         {
             repository =>
                'https://github.com/wu-lee/Text-Glob-Expand',
        },
        keywords  => [qw(text glob pattern expand braces hostnames)],
     },
     configure_requires => 
     {
         'Module::Build' => 0.28,
     },
     build_requires => 
     {
         'Module::Build' => 0.28,
     },
     requires => 
     {
      'Test::More' => 0,
      'version'    => 0.77,
     },
     recommends => 
     {
     },
     test_files         => [ rscan_dir('t', '\.t$'), rscan_dir('xt', '\.t$') ],
     add_to_cleanup      => [ 'Text-Glob-Expand-*' ],
    );

$builder->create_build_script();
