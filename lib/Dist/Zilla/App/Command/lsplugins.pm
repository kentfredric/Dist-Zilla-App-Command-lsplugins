use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package Dist::Zilla::App::Command::lsplugins;

our $VERSION = '0.001001';

# ABSTRACT: Show all C<dzil> plugins on your system, with descriptions

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moose qw( has );
use MooseX::NonMoose;
use Dist::Zilla::App '-command';












has _inc_scanner => ( is => ro =>, lazy_build => 1 );
has _plugin_dirs => ( is => ro =>, lazy_build => 1 );

sub _build__inc_scanner {
  require Path::ScanINC;
  return Path::ScanINC->new();
}

sub _build__plugin_dirs {
  my ($self) = @_;
  return [ $self->_inc_scanner->all_dirs( 'Dist', 'Zilla', 'Plugin' ) ];
}

sub _plugin_dir_iterator {
  my ($self) = @_;
  my @dirs = @{ $self->_plugin_dirs };
  return sub {
    return unless @dirs;
    return shift @dirs;
  };
}

sub _plugin_all_files_iterator {
  my ($self) = @_;
  my $dir_iterator = $self->_plugin_dir_iterator;
  my $dir;
  my $file_iterator;
  my $code;
  $code = sub {
    if ( not defined $dir ) {
      if ( not defined( $dir = $dir_iterator->() ) ) {
        return;
      }
      require Path::Tiny;
      $file_iterator = Path::Tiny->new($dir)->iterator(
        {
          recurse         => 1,
          follow_symlinks => 0,
        },
      );
    }
    my $file = $file_iterator->();
    if ( not defined $file and defined $dir ) {
      $dir = undef;
      goto $code;
    }
    return [ $dir, $file ];
  };
  return $code;
}

sub _plugin_iterator {
  my ($self) = @_;

  my $file_iterator = $self->_plugin_all_files_iterator;

  my $is_plugin = sub {
    my ($file) = @_;
    return unless $file =~ /[.]pm\z/msx;
    return if -d $file;
    return 1;
  };

  my $code;
  my $end;
  $code = sub {
    return if $end;
    my $file = $file_iterator->();
    if ( not defined $file ) {
      $end = 1;
      return;
    }
    if ( $is_plugin->( $file->[1] ) ) {
      require Dist::Zilla::lsplugins::Module;
      return Dist::Zilla::lsplugins::Module->new(
        file            => $file->[1],
        plugin_root     => $file->[0],
        plugin_basename => 'Dist::Zilla::Plugin',
      );
    }
    goto $code;
  };
  return $code;
}





















































sub opt_spec {
  return (
    [ q[sort!],     q[Sort by module name] ],
    [ q[versions!], q[Show versions] ],
    [ q[abstract!], q[Show Abstracts] ],
    [ q[roles=s],   q[Show applied roles] ],
    [ q[with=s],    q[Filter plugins to ones that 'do' the specified role] ]
  );
}

sub _filter_dzil {
  my ($value) = @_;
  return ( $value =~ /(\A|[|])Dist::Zilla::Role::/msx );
}

sub _shorten_dzil {
  my ($value) = @_;
  $value =~ s/(\A|[|])Dist::Zilla::Role::/$1-/msxg;
  return $value;
}

sub _process_plugin {
  my ( undef, $plugin, $opt, undef ) = @_;
  if ( defined $opt->with ) {
    return unless $plugin->loaded_module_does( $opt->with );
  }
  printf q[%s], $plugin->plugin_name;
  if ( $opt->versions ) {
    printf q[ (%s)], $plugin->version;
  }
  if ( $opt->abstract ) {
    printf q[ - %s], $plugin->abstract;
  }
  if ( defined $opt->roles ) {
    if ( $opt->roles eq 'all' ) {
      printf q{ [%s]}, join q[, ], @{ $plugin->roles };
    }
    elsif ( $opt->roles eq 'dzil-full' ) {
      printf q{ [%s]}, join q[, ], grep { _filter_dzil($_) } @{ $plugin->roles };
    }
    elsif ( $opt->roles eq 'dzil' ) {
      printf q{ [%s]}, join q[, ], map { _shorten_dzil($_) } grep { _filter_dzil($_) } @{ $plugin->roles };
    }
  }
  printf "\n";
  return;
}









sub execute {
  my ( $self, $opt, $args ) = @_;

  if ( !$opt->sort ) {
    my $plugin_iterator = $self->_plugin_iterator;

    while ( my $plugin = $plugin_iterator->() ) {
      $self->_process_plugin( $plugin, $opt, $args );
    }
    return 0;
  }

  my $plugin_iterator = $self->_plugin_iterator;
  my @plugins;
  while ( my $plugin = $plugin_iterator->() ) {
    push @plugins, $plugin;
  }
  for my $plugin ( sort { $a->plugin_name cmp $b->plugin_name } @plugins ) {
    $self->_process_plugin( $plugin, $opt, $args );
  }
  return 0;

}
__PACKAGE__->meta->make_immutable;
no Moose;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::App::Command::lsplugins - Show all C<dzil> plugins on your system, with descriptions

=head1 VERSION

version 0.001001

=head1 SYNOPSIS

    dzil lsplugins # see a list of all plugins on your system
    dzil lsplugins --version # with versions!
    dzil lsplugins --sort    # sort them!
    dzil lsplugins --abstract # show their ABSTRACTs!
    dzil lsplugins --with=-FilePruner # show only file pruners
    dzil lsplugins --roles=dzil  # show all the dzil related role data!

=head1 METHODS

=head2 C<opt_spec>

Supported parameters:

=over 4

=item * C<--sort>

Sorting.

=item * C<--no-sort>

No Sorting ( B<Default> )

=item * C<--versions>

Versions

=item * C<--no-versions>

No Versions ( B<Default> )

=item * C<--abstract>

Show abstracts

=item * C<--no-abstract>

Don't show abstracts ( B<Default> )

=item * C<--roles=all>

Show all roles, un-abbreviated.

=item * C<--roles=dzil-full>

Show only C<dzil> roles, un-abbreviated.

=item * C<--roles=dzil>

Show only C<dzil> roles, abbreviated.

=item * C<--with=$ROLENAME>

Show only plugins that C<< does($rolename) >>

( A - prefix will be expanded to C<Dist::Zilla::Role::> for convenience )

=back

=for Pod::Coverage execute

=head1 AUTHOR

Kent Fredric <kentfredric@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
