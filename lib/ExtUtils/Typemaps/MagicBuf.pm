package ExtUtils::Typemaps::MagicBuf;

use strict;
use warnings;

use parent 'ExtUtils::Typemaps';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->add_inputmap(xstype => 'T_MAGICBUF', code =>  <<'END');
	{
	MAGIC* magic = SvROK($arg) && SvMAGICAL(SvRV($arg)) ? mg_findext(SvRV($arg), PERL_MAGIC_ext, NULL) : NULL;
	if (magic)
		$var = (${type})magic->mg_ptr;
	else
		Perl_croak(aTHX_ \"${ntype} object is lacking magic\");
	}
END

	$self->add_outputmap(xstype => 'T_MAGICBUF', code => '	sv_magic(newSVrv($arg, \"${ntype}\"), NULL, PERL_MAGIC_ext, (const char*)$var, sizeof(*$var));');

	return $self;
}

1;

# ABSTRACT: Typemap for storing objects in magic

=head1 SYNOPSIS

In your typemap

 My::Object	T_MAGICBUF

In your XS:

 typedef struct object_t* My__Object;

 MODULE = My::Object    PACKAGE = My::Object    PREFIX = object_

 My::Object object_new(int argument)

 int object_baz(My::Object self)

=head1 DESCRIPTION

C<ExtUtils::Typemaps::MagicBuf> is an C<ExtUtils::Typemaps> subclass that is the equivalent of using a string reference to store your object in, except it is hidden away using magic. This is suitable for objects that can be safely shallow copied on thread cloning (i.e. they don't contain external references such as pointers or file descriptors). Unlike C<T_MAGIC> or C<T_PTROBJ> this does not need a C<DESTROY> method to free the buffer.

=head1 DEPENDENCIES

On perls older than C<5.14>, this will require F<ppport.h> to provide C<mg_findext>. E.g.

 #define NEED_mg_findext
 #include "ppport.h"
