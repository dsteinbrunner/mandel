package Mandel;

=head1 NAME

Mandel - Async model layer for MongoDB objects using Mango

=head1 SYNOPSIS

  package MyModel;
  use Mandel;

  package MyModel::Person;
  use Mandel::Document;
  field [qw( name age )];
  has_many cats => 'MyModel::Cat';
  has_one favorite_cat => 'MyModel::Cat';

  package MyApp;
  my $mandel = MyModel->new(uri => 'mongodb://localhost/mandeltest');
  my $persons = $mandel->collection('person');

  {
    my $p1 = $persons->create({ name => 'Bruce', age => 30 });
    $p1->save(sub {});
  }

  $persons->count(sub {
    my($persons, $n_persons) = @_;
  });

  $persons->all(sub {
    my($persons, $err, $objs) = @_;
    for my $p (@$objs) {
      $p->age(25)->save(sub {});
    }
  });

  $persons->search({ name => 'Bruce' })->single(sub {
    my($persons, $obj) = @_;
    $obj->cats(sub {
      my($obj, $err, $cats) = @_;
      $_->remove(sub {}) for @$cats;
    });
  });

=head1 DESCRIPTION

L<Mandel> is an async object-document-mapper. It allows you to work with your
MongoDB documents in Perl as objects.

This class binds it all together:

=over 4

=item * L<Mandel::Description>

An object describing a document.

=item * L<Mandel::Collection>

A collection of Mandel documents.

=item * L<Mandel::Document>

A single MongoDB document with logic.

=back

=cut

use Mojo::Base 'Mojo::Base';
use Mojo::Loader;
use Mojo::Util;
use Mandel::Collection;
use Mango;
use Carp;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

my $LOADER = Mojo::Loader->new;

=head1 ATTRIBUTES

L<Mandel> inherits all attributes from L<Mojo::Base> and implements the
following new ones.

=head2 mango

An instance of L<Mango> which acts as the database connection. If not
provided, one will be lazily created using the L</uri> attribute.

=head2 namespaces

The namespaces which will be searched when looking for Types. By default, the
(sub)class name of this module.

=head2 uri

The uri used by L<Mango> to connect to the MongoDB server.

IMPORTANT! It requires the database to be part of the URI. Example:

  mongodb://localhost/my_database_name

=cut

has mango => sub { Mango->new( shift->uri or croak 'Please provide a uri' ) };
has namespaces => sub { [ ref $_[0] ] };
has uri => 'mongodb://localhost/mandeltest';

=head1 METHODS

L<Mandel> inherits all methods from L<Mojo::Base> and implements the following
new ones.

=head2 initialize

  $self->initialize(@names);
  $self->initialize;

Takes a list of document names. Calls the L<Mango::Document/initialize> method
on any document given as input. C<@names> default to L</all_document_names>
unless specified.

=cut

sub initialize {
  my $self = shift;
  my @documents = @_ ? @_ : $self->all_document_names;

  for my $document ( @documents ) {
    my $class = $self->class_for($document);
    my $collection = $self->mango->db->collection($class->collection);
    $class->initialize($self, $collection);
  }
}

=head2 all_document_names

  @names = $self->all_document_names;

Returns a list of all the documents in the L</namespaces>.

=cut

sub all_document_names {
  my $self = shift;
  my @names;

  for my $ns (@{ $self->namespaces }) {
    for my $name (@{ $LOADER->search($ns) }) {
      $name =~ s/^${ns}:://;
      push @names, Mojo::Util::decamelize($name);
    }
  }

  @names;
}

=head2 class_for

  $document_class = $self->class_for($name);

Given a document name, find the related class name, ensure that it is loaded
(or else die) and return it.

=cut

sub class_for {
  my ($self, $name) = @_;

  if(my $class = $self->{loaded}{$name}) {
    return $class;
  }

  for my $ns (@{ $self->namespaces }) {
    my $class = $ns . '::' . Mojo::Util::camelize($name);
    my $e = $LOADER->load($class);
    die $e if ref $e;
    next if $e;
    return $self->{loaded}{$name} = $class
  }

  Carp::carp "Could not find class for $name";
}

=head2 collection

  $collection_obj = $self->collection($name);

Returns a L<Mango::Collection> object.

=cut

sub collection {
  my($self, $name) = @_;
  my $document_class = $self->class_for($name);

  Mango::Collection->new(
    document_class => $document_class,
    model => $self,
  );
}

=head2 import

See L</SYNOPSIS>.

=cut

sub import {
  my($class) = @_;
  my $caller = caller;

  @_ = ($class, __PACKAGE__);
  goto &Mojo::Base::import;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>

=head1 SOURCE REPOSITORY

L<http://github.com/jhthorsen/mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

This project is a fork of L<MangoModel|http://github.com/jberger/MangoModel>,
created by Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Jan Henning Thorsen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
