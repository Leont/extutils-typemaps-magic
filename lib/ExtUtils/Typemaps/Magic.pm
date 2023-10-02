package ExtUtils::Typemaps::Magic;

use strict;
use warnings;

use parent 'ExtUtils::Typemaps';

sub new {
	my $class = shift;

	my $self = $class->SUPER::new(@_);

	my $input = <<'END';
	{
	MAGIC* magic = SvROK($arg) && SvMAGICAL(SvRV($arg)) ? mg_findext(SvRV($arg), PERL_MAGIC_ext, %s) : NULL;
	if (magic)
		$var = (${type})magic->mg_ptr;
	else
		Perl_croak(aTHX_ \"${ntype} object is lacking magic\");
	}
END

	$self->add_inputmap(xstype => 'T_MAGIC', code => sprintf $input, 'NULL');
	$self->add_inputmap(xstype => 'T_MAGICBUF', code => sprintf $input, 'NULL');
	$self->add_inputmap(xstype => 'T_MAGICEXT', code => sprintf $input, '&${type}_magic');

	$self->add_outputmap(xstype => 'T_MAGIC', code => '	sv_magic(newSVrv($arg, \"${ntype}\"), NULL, PERL_MAGIC_ext, (const char*)$var, 0);');
	$self->add_outputmap(xstype => 'T_MAGICBUF', code => '	sv_magic(newSVrv($arg, \"${ntype}\"), NULL, PERL_MAGIC_ext, (const char*)$var, sizeof(*$var));');

	$self->add_outputmap(xstype => 'T_MAGICEXT', code => <<'END');
	{
	MAGIC* magic = sv_magicext(newSVrv($arg, \"${ntype}\"), NULL, PERL_MAGIC_ext, &${type}_magic, (const char*)$var, 0);
	magic->mg_flags |= MGf_COPY|MGf_DUP;
	}
END

	return $self;
}

sub minimum_pxs {
	return '3.50';
}

1;

# ABSTRACT: Typemap for storing objects in magic

=head1 SYNOPSIS

 use ExtUtils::Typemaps::Magic;
 # First, read my own type maps:
 my $private_map = ExtUtils::Typemaps->new(file => 'my.map');

 # Then, get the Magic set and merge it into my maps
 my $map = ExtUtils::Typemaps::Magic->new;
 $private_map->merge(typemap => $map);

 # Now, write the combined map to an output file
 $private_map->write(file => 'typemap');

=head1 DESCRIPTION

C<ExtUtils::Typemaps::Magic> is an C<ExtUtils::Typemaps> subclass that provides three magic based mappings for objects:

=head2 T_MAGIC

This is essentially a drop-in replacement for C<T_PTROBJ>, except that it hides the value of the pointer from pure-perl code by storing it in attached magic. In particular that means the pointer won't be serialized/deserialized (this is usually a thing because after deserialization the pointer is probably not valid). Note that like C<T_PTROBJ>, you probably need a C<DESTROY> method to destroy and free the buffer. Like C<T_PTROBJ> and friends, this is not thread cloning safe without further measures.

=head2 T_MAGICBUF

This is equivalent of using a string reference to store your object in, except it is hidden away using magic. This is suitable for objects that can be safely shallow copied on thread cloning (i.e. they don't contain external references such as pointers or file descriptors). Unlike C<T_MAGIC> or C<T_PTROBJ> this does not need a C<DESTROY> method to free the buffer.

=head2 T_MAGICEXT

This stores the object just like C<T_MAGIC> does, but additionally attaches a magic vtable (type C<MGVTBL>) with the name C<${type}_magic> (e.g. C<Foo__Bar_magic> for a value of type C<Foo::Bar>) to the value. This is mainly useful for adding C<free> (destruction) and C<dup> (thread cloning) callbacks. The details of how these work is explained in L<perlguts|perlguts>, but it might look something like this:

 static int object_dup(pTHX_ MAGIC* magic, CLONE_PARAMS* params) {
     object_refcount_increment((struct Object*)magic->mg_ptr);
     return 0;
 }

 static int object_free(pTHX_ SV* sv, MAGIC* magic) {
     object_refcount_decrement((struct Object*)magic->mg_ptr);
     return 0;
 }

 static const MGVTBL My__Object_magic = { NULL, NULL, NULL, NULL, object_free, NULL, object_dup, NULL };

This is useful to create objects that handle thread cloning correctly and effectively. The object should be allocated with the C<PerlSharedMem_malloc> family of allocators.

=head1 DEPENDENCIES

The C<T_MAGICEXT> typemap requires L<ExtUtils::ParseXS|ExtUtils::ParseXS> C<3.50> or higher.

On perls older than C<5.14>, this will require F<ppport.h> to provide C<mg_findext>.
