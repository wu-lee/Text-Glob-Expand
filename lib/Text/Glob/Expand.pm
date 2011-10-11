package Text::Glob::Expand;
use Text::Glob::Expand::Segment;
use Text::Glob::Expand::Permutation;
use warnings;
use strict;
use Carp;
use Scalar::Util qw(refaddr);

use version; our $VERSION = qv('0.1');

# Cache ->_explode results here
our %CACHE;

# and queue cached items for deletion
our @CACHE_QUEUE;

# when the number of cached items exceeds this.
our $MAX_CACHING = 100;

######################################################################
# Private functions

sub _partition {
    my $depth = shift;
    my @partitions;
    my $partition;
    foreach my $elem (@_) {
        if ($elem->depth > $depth) {
            push @$partition, $elem;
        }
        else {
            push @partitions, $partition
                if $partition 
                    && @$partition;
            $partition = [];
        }
    }
    push @partitions, $partition
        if @$partition;
    return @partitions;
}

######################################################################
# Private methods

sub _traverse {
    my $self = shift;
    return [] unless @_;
    my $first = shift;
    
    if (ref $first eq 'Text::Glob::Expand::Segment') {
        # we have a string segment
        return [[$first]] unless @_;
        
        my $exploded = $self->_traverse(@_);
        unshift @$_, $first for @$exploded;
        return $exploded;
    }
    else {
            # we have a arrayref of alternatives from a brace
        my @exploded;
        foreach my $seq (@$first) {
            die "unexpected scalar '$seq'" if !ref $seq;
            my $exploded2 = $self->_traverse(@$seq, @_);
            push @exploded, @$exploded2;
        }
        return \@exploded;
    }
}


sub _transform {
    my $self = shift;
    my $depth = shift;
    my $permutation = shift;
    my $flat =  join '', map { $_->[0] } @$permutation; 
    if (my @deeper = _partition $depth, @$permutation) {
        return bless (
            [$flat, map { $self->_transform($depth+1, $_)} @deeper], 
            'Text::Glob::Expand::Permutation',
        );
    }
    return bless [$flat], 'Text::Glob::Expand::Permutation';
}


######################################################################
# Public methods

sub parse {
    my $class = shift;
    my $str = shift;

    my $pos;
    my $depth = 0;

    my $new_segment = sub { bless ['', $depth], 'Text::Glob::Expand::Segment' };

    my @c_stack = $new_segment->();
    my @alt_count = ();
    my @seq_count = (1);

    my $add_char = sub {
        $c_stack[-1][0] .= $_;
    };

    my $start_brace = sub {
        ++$depth;
        push @c_stack, $new_segment->();
        push @alt_count, 1;
        ++$seq_count[-1];
        push @seq_count, 1;
    };

    my $new_alternative = sub {
        my $num_elems = pop @seq_count;
        push @c_stack, [splice @c_stack, -$num_elems], $new_segment->();
        ++$alt_count[-1];
        push @seq_count, 1;
    };

    my $end_brace = sub {
        --$depth;
        my $num_elems = pop @seq_count;
        push @c_stack, [splice @c_stack, -$num_elems];
        $num_elems = pop @alt_count;
        push @c_stack, [splice @c_stack, -$num_elems], $new_segment->();
        ++$seq_count[-1];
    };
    

    my $states = {
        start => {
            '\\' => sub {
                'escape'
            },
            '{' => sub {
                $start_brace->();
                'start';
            },
            '}' => sub {
                $end_brace->();
                'start';
            },
            ',' => sub {
                @alt_count?
                    $new_alternative->() :
                    $add_char->() ; # possibly this should be illegal?
                'start';
            },
            '' => sub {
                $add_char->();
                'start';
            }
        },
        

        escape => {
            '' => sub { 
                $add_char->();
                'start';
            },
        }
    };
        
    
    my $state = 'start';
    for $pos (0..length($str)-1) { ## no critic RequireLexicalLoopIterators 
        my $table = $states->{$state}
            or die "no such state '$state'";
        
        for (substr $str, $pos, 1) {
            my $action =
                $table->{$_} || 
                $table->{''} ||
                die "no handler for state '$state' looking at '$_' pos $pos";
        
            $state = $action->();
        }
    }

    return bless \@c_stack, __PACKAGE__;
};


# Uncached version
sub _explode {
    my $self = shift;

    # calculate result
    my $exploded = $self->_traverse(@$self);

    return [map { $self->_transform(0, $_) } @$exploded];
}

sub explode {
    my $self = shift;

    # handle caching
    if ($MAX_CACHING > 0) {
        # get (possibly cached) result
        my $id = refaddr $self;
        my $exploded = $CACHE{$id};
        return $exploded 
            if $exploded;

        $exploded = $self->_explode(@$self);

        unshift @CACHE_QUEUE, $id;
        if (@CACHE_QUEUE > $MAX_CACHING) {
            delete @CACHE{splice @CACHE_QUEUE, $MAX_CACHING};
        }

        return $exploded;
    }

    %CACHE = ();
    @CACHE_QUEUE = ();

    return $self->_explode(@$self);
}

sub explode_format {
    my $self = shift;
    my $format = shift;

    my $exploded = $self->explode;
    
    return {map { $_->text => $_->expand($format) } @$exploded};
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Text::Glob::Expand - permute and expand glob-like text patterns


=head1 VERSION

This document describes Text::Glob::Expand version 0.1


=head1 SYNOPSIS

The original use case was to specify hostname aliases and expansions
thereof.  For example:

    use Text::Glob::Expand;

    my $hosts = "{www{1,2,3},mail{1,2},ftp{1,2}}";
    my $glob = Text::Glob::Expand->parse($hosts);

    my $permutations = $glob->explode("%1.somewhere.co.uk");
    # $permutations = [qw(www1 www2 www3 mail1 mail2 ftp1 ftp2)]

    my $permutations = $glob->explode_format("%0.somewhere.co.uk");
    # $permutations = {
    #     www1 => 'www1.somewhere.co.uk',
    #     www2 => 'www2.somewhere.co.uk',
    #     www3 => 'www3.somewhere.co.uk',
    #     mail1 => 'mail1.somewhere.co.uk',
    #     mail2 => 'mail2.somewhere.co.uk',
    #     ftp1 => 'ftp1.somewhere.co.uk',
    #     ftp2 => 'ftp2.somewhere.co.uk',
    # }
  
=head1 INTERFACE 


=head2 C<< $obj = $class->parse($string) >>

This is the constructor.  It parses a string, and returns a
C<Text::Glob::Expand> object.

=head2 C<< $arrayref = $obj->explode >>

This returns an arrayref containing all the expanded permutations
generated from the string parsed by the constructor.

(The result is cached, and returned again if this is called more than
once.  See C<$MAX_CACHING>.)

=head2 C<< $hashref = $obj->explode_format($format) >>

This returns a hashref mapping each expanded permutation to a string
generated from the C<$format> parameter.

(The return value is not cached, since the result depend on C<$format>.)


=head1 DIAGNOSTICS

TBD

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT

C<Text::Glob::Expand> requires no configuration files or environment variables.

There is one configurable option in the form of a package variable.

=head2 C<$MAX_CACHING>

The package variable C<$Text::Glob::Expand::MAX_CACHING> can be used
to control or disable the caching done by the C<< ->explode >> method.
It should be a positive integer, or zero.

The default value is 100, which means that up to 100
C<Text::Glob::Expand> objects' C<< ->explode >> results will be
cached, but no more.  You can disable caching by setting this to zero
or less.

=head1 DEPENDENCIES

The dependencies should be minimal - I aim to have none.

For a definitive answer, see the Build.PL file included in the
distribution, or use the dependencies tool on
L<http://search.cpan.org>

=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-Text-Glob-Expand@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


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
