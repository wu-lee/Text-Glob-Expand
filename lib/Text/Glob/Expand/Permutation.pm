package Text::Glob::Expand::Permutation;
use strict;
use warnings;
use Carp qw(croak);

sub text { shift->[0] }

sub _percent_expand {
    my $self = shift;
    my $match = shift;
    
    if ($match eq "%") {
        return "%";
    }
    
    if ($match eq "0") {
        return $self->[0];
    }
    
    my $curr = $self;
    my @digits = split /[.]/, $1;
    
    while(@digits) {
        my $digit = shift @digits;
        
        die "invalid capture name %$1 (contains zero)"
            unless $digit > 0; 
        $curr = $curr->[$digit];
        die "invalid capture name %$1 (reference to non-existent brace))\n"
            unless $curr && ref $curr;
    }
    return $curr->[0]
}

sub expand {
    my ($self, $format) = @_;
    croak "you must supply a format string to expand"
        unless defined $format;
    
    eval {
        $format =~
            s{
                 %
                 (
                     %
                 |
                     (?: \d+ [.] )*
                     \d+
                 )
             }
             {
                 $self->_percent_expand($1)
             }gex;
        1;
    }
    or do {
        chomp(my $error = $@);
        croak "$error when applying '$self->[0]' to '$format'";
    };
    
    return $format;
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Text::Glob::Expand::Permutation - describes one possible expansion of a glob pattern

=head1 SYNOPSIS

This is an internal class, returned in the which you won't normally
create as a user.  C<< Text::Glob::Expand->explode >> returns an
arrayref containing objects of this class.

It can be used to get the permutation text, or a formatted version of
the permutation's components.

   ($first, @rest) = Text::Glob::Expand->parse("a{b,c}");
   print $first->text;
   # "ab"

   print $first->expand("text is %0 and first brace is %1"); 
   # "text is ab and first brace is b"

=head1 INTERFACE 

=head2 C<< $str = $obj->text >>

Returns the unembellished text of this permutation.

=head2 C<< $str = $obj->expand($format) >>>

Returns the string C<$format> expanded with the components of the permutation.

The following expansions are made:

=over 4

=item C<%%> 

An escaped percent, expands to C<%>

=item C<%0>

Expands to the whole permutation text, the same as returned by C<< ->text >>.

=item C<%n>

(Where C<n> is a positive decimal number.)  Expands to this permutation's
contribution from the nth brace (numbering starts at 1).

This may throw an exception if the number is larger than the number of braces.

=item C<%n.n>

(Where C<n.n> is a sequence of positive decimal numbers, delimited by
periods.)  Expands to this permutations contribution from a nested
brace, if it exists (otherwise an error will be thrown).

So, for example, C<%1.1> is the first nested brace within the first
brace, and C<%10,3,2> is the second brace within the third brace
within the 10th brace.

=back


=head1 DIAGNOSTICS

TDB

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=head1 AUTHOR

Nick Stokoe  C<< <npw@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011, Nick Stokoe C<< <npw@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
