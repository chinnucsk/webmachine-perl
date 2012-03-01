package Web::Machine::Util::MediaType;

use strict;
use warnings;

use Scalar::Util qw[ blessed ];
use Carp         qw[ confess ];

use Tie::IxHash;
use Syntax::Keyword::Junction qw[ any ];

use overload '""' => 'to_string', fallback => 1;

sub new {
    my $class = shift;
    my %args  = ref $_[0] ? %{ $_[0] } : @_;

    (exists $args{'type'})
        || confess "The type parameter is required";

    bless {
        type   => $args{'type'},
        params => $args{'params'} || {}
    } => $class;
}

sub type   { (shift)->{'type'}   }
sub params { (shift)->{'params'} }

sub new_from_string {
    my ($class, $media_type) = @_;
    if ( $media_type =~ /^\s*([^;\s]+)\s*((?:;\s*\S+\s*)*)\s*$/ ) {
        my ($type, $raw_params) = ($1, $2);
        # NOTE:
        # if the media type comes in as a
        # string, we want to be able to
        # round-trip it, so we need to
        # make sure the hash retains its
        # ordering.
        # - SL
        my %params;
        tie %params, 'Tie::IxHash', ($raw_params =~ /;\s*([^=]+)=([^;=\s]+)/g);
        return $class->new( type => $type, params => \%params );
    }
    confess "Unable to parse media type from '$media_type'"
}

sub major { (split '/' => (shift)->type)[0] }
sub minor { (split '/' => (shift)->type)[1] }

sub to_string {
    my $self = shift;
    join ';' => $self->type, map { join '=' => $_, $self->params->{ $_ } } keys %{ $self->params };
}

sub matches_all {
    my $self = shift;
    $self->type eq '*/*' && $self->params_are_empty
        ? 1 : 0;
}

## ...

# must be exactly the same
sub equals {
    my ($self, $other) = @_;
    $other = (ref $self)->new_from_string( $other ) unless blessed $other;
    $other->type eq $self->type && _compare_params( $self->params, $other->params )
        ? 1 : 0;
}

# types must be compatible and params much match exactly
sub exact_match {
    my ($self, $other) = @_;
    $other = (ref $self)->new_from_string( $other ) unless blessed $other;
    $self->type_matches( $other ) && _compare_params( $self->params, $other->params )
        ? 1 : 0;
}

# types must be be compatible and params should align
sub match {
    my ($self, $other) = @_;
    $other = (ref $self)->new_from_string( $other ) unless blessed $other;
    $self->type_matches( $other ) && $self->params_match( $other->params )
        ? 1 : 0;
}

## ...

sub type_matches {
    my ($self, $other) = @_;
    return 1 if any('*', '*/*', $self->type) eq $other->type;
    $other->major eq $self->major && $other->minor eq '*'
        ? 1 : 0;
}

sub params_match {
    my ($self, $other) = @_;
    my $params = $self->params;
    foreach my $k ( keys %$other ) {
        return 0 if not exists $params->{ $k };
        return 0 if $params->{ $k } ne $other->{ $k };
    }
    return 1;
}

sub params_are_empty {
    my $self = shift;
    (scalar keys %{ $self->params }) == 0 ? 1 : 0
}

## ...

sub _compare_params {
    my ($left, $right) = @_;
    my @left_keys  = sort keys %$left;
    my @right_keys = sort keys %$right;

    return 0 unless (scalar @left_keys) == (scalar @right_keys);

    foreach my $i ( 0 .. $#left_keys ) {
        return 0 unless $left_keys[$i] eq $right_keys[$i];
        return 0 unless $left->{ $left_keys[$i] } eq $right->{ $right_keys[$i] };
    }

    return 1;
}

1;

__END__

# ABSTRACT: A Moosey solution to this problem

=head1 SYNOPSIS

  use Web::Machine::Util::MediaType;

=head1 DESCRIPTION

