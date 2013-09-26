package Mandel::Description;

=head1 NAME

Mandel::Description - An object describing a document

=cut

use Mojo::Base -base;
use Mojo::Loader;
use Mojo::Util;

my $LOADER = Mojo::Loader->new;

=head1 ATTRIBUTES

=head2 collection

=head2 document_class

=cut

has collection => '';
has document_class => '';

=head1 METHODS

=head2 add_field

  $self = $self->add_field('name');
  $self = $self->add_field(['name1', 'name2']);

Used to add new field(s) to this document.

=cut

sub add_field {
  my($self, $fields) = @_;
  my $class = $self->document_class;

  # Compile fieldibutes
  for my $field (@{ref $fields eq 'ARRAY' ? $fields : [$fields]}) {
    my $code = "package $class;\nsub $field {\n my \$r = \$_[0]->_raw;";
    $code .= "if (\@_ == 1) {\n";
    $code .= "    \$_[0]->{updated}=1;";
    $code .= "    return \$r->{'$field'};";
    $code .= "\n  }\n  \$r->{'$field'} = \$_[1];\n";
    $code .= "  \$_[0];\n}";

    # We compile custom attribute code for speed
    no strict 'refs';
    warn "-- Attribute $field in $class\n$code\n\n" if $ENV{MOJO_BASE_DEBUG};
    Carp::croak "Mandel::Document error: $@" unless eval "$code;1";
  }

  $self;
}

=head2 add_relationship

  $self->add_relationship(has_one => $field_name => 'Other::Document::Class');

See L<Mandel::Relationship::HasMany> and L<Mandel::Relationship::HasOne>.

=cut

sub add_relationship {
  my($self, $type, $field, $other) = @_;
  my $class = 'Mandel::Relationship::' .Mojo::Util::camelize($type);
  my $e = $LOADER->load($class);

  die $e if ref $e;
  $class->create($self->document_class, $field, $other);
  $class->{relationship}{$field} = $class; # TODO: The value can be redefined any time
  $self;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;