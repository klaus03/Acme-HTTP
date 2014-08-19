use strict;
use warnings;
use 5.008;

use Module::Build;

Module::Build->new(
  module_name        => 'Acme::HTTP',
  license            => 'perl',
  configure_requires => { 'Module::Build' => 0 },
  requires           => {
    'Net::HTTP'       => 0,
    'Net::HTTPS'      => 0,
    'IO::Socket::SSL' => 0,
    'Net::SSL'        => 0,
  },
  dist_abstract      => 'High-level access to Net::HTTP and Net::HTTPS',
)->create_build_script;
