package Text::Glob::Expand;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.1');

use Exporter qw(import);

our @EXPORT_OK = qw(parse_glob parse_glob_with_depth explode explode_with_structure);

sub parse_glob {
    my $str = shift;

    my $pos;

    my @c_stack = ('');
    my @alt_count = ();
    my @seq_count = (1);

    my $add_char = sub {
        $c_stack[-1] .= $_;
    };

    my $start_brace = sub {
        push @c_stack, '';
        push @alt_count, 1;
        ++$seq_count[-1];
        push @seq_count, 1;
    };

    my $new_alternative = sub {
        my $num_elems = pop @seq_count;
        push @c_stack, [splice @c_stack, -$num_elems], '';
        ++$alt_count[-1];
        push @seq_count, 1;
    };

    my $end_brace = sub {
        my $num_elems = pop @seq_count;
        push @c_stack, [splice @c_stack, -$num_elems];
        $num_elems = pop @alt_count;
        push @c_stack, [splice @c_stack, -$num_elems], '';
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
    for $pos (0..length($str)-1) {
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

    return \@c_stack;
};

sub parse_glob_with_depth {
    my $str = shift;

    my $pos;
    my $depth = 0;

    my $new_segment = sub { ['', $depth] };

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
    for $pos (0..length($str)-1) {
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

    return \@c_stack;
};

sub explode {
    my $traverse;

    $traverse = sub {
        return [] unless @_;
        my $first = shift;

        if (!ref $first) {
            # we have a string segment
            return [[$first]] unless @_;
            
            my $exploded = $traverse->(@_);
            unshift @$_, $first for @$exploded;
            return $exploded;
        }
        else {
            # we have a arrayref of alternatives from a brace
            my @exploded;
            foreach my $seq (@$first) {
                die "unexpected scalar" if !ref $seq;
                my $exploded2 = $traverse->(@$seq, @_);
                push @exploded, @$exploded2;
            }
            return \@exploded;
        }
    };

    my $parsed_glob = shift;
    return $traverse->(@$parsed_glob);
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Text::Glob::Expand - [One line description of module's purpose here]


=head1 VERSION

This document describes Text::Glob::Expand version 0.1


=head1 SYNOPSIS

    use Text::Glob::Expand;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Text::Glob::Expand requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


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
