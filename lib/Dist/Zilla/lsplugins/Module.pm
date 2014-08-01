use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::lsplugins::Module;

our $VERSION = '0.001001';

# ABSTRACT: Transient data about a traversed plugin/role/module

# AUTHORITY

use Moose;
use Try::Tiny;

has 'file'             => ( is => ro =>, required   => 1 );
has 'plugin_root'      => ( is => ro =>, required   => 1 );
has 'plugin_basename'  => ( is => ro =>, required   => 1 );
has 'plugin_name'      => ( is => ro =>, lazy_build => 1 );
has '_version'         => ( is => ro =>, lazy_build => 1 );
has 'version'          => ( is => ro =>, lazy_build => 1 );
has 'abstract'         => ( is => ro =>, lazy_build => 1 );
has 'roles'            => ( is => ro =>, lazy_build => 1 );
has '_module_metadata' => ( is => ro =>, lazy_build => 1 );
has '_loaded_module'   => ( is => ro =>, lazy_build => 1 );

sub _build_plugin_name {
  my ($self) = @_;
  my $rpath = $self->file->relative( $self->plugin_root );
  $rpath =~ s/[.]pm\z//msx;
  $rpath =~ s{/}{::}gmsx;
  return $rpath;
}

sub _build_version {
  my ($self) = @_;
  my $v = $self->_version;
  return $v if defined $v;
  return 'undef';
}

sub _build__module_metadata {
  my ($self) = @_;
  require Module::Metadata;
  return Module::Metadata->new_from_file( $self->file );
}

sub _build__version {
  my ($self) = @_;
  return $self->_module_metadata->version;
}

sub _build_abstract {
  my ($self) = @_;
  require Dist::Zilla::Util;
  ## no critic ( Subroutines::ProtectPrivateSubs )
  my $e = Dist::Zilla::Util::PEA->_new();
  $e->read_string( $self->file->slurp_utf8 );
  return $e->{abstract};
}

sub _build__loaded_module {
  my ($self) = @_;
  require Module::Runtime;
  my $module = $self->plugin_basename . q[::] . $self->plugin_name;
  my $failed = 0;
  try {
    Module::Runtime::require_module($module);
  }
  catch {
    require Carp;
    Carp::carp( q[Uhoh, ] . $module . q[ failed to load] );
    ## no critic (ErrorHandling::RequireCarping)
    warn $_;
    $failed = 1;
  };
  return if $failed;
  return $module;
}

sub _build_roles {
  my ($self) = @_;
  my $module = $self->_loaded_module();
  return [] if not defined $module;
  return [] if not $module->can('meta');
  return [] if not $module->meta->can('calculate_all_roles_with_inheritance');
  my @roles = $module->meta->calculate_all_roles_with_inheritance;
  my @out;
  for my $role (@roles) {
    push @out, $role->name;
  }
  return \@out;
}

=method C<loaded_module_does>

Loads the module, using C<_loaded_module>, and returns C<undef>
as soon as it can't proceed further.

If it can proceed to calling C<does>, it will return true if the C<plugin> C<does> the specified role.

=cut

sub loaded_module_does {
  my ( $self, $role ) = @_;
  $role =~ s/\A-/Dist::Zilla::Role::/msx;
  return unless $self->_loaded_module;
  return unless $self->_loaded_module->can('does');
  return $self->_loaded_module->does($role);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

