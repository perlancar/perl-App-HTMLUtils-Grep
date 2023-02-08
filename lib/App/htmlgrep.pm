## no critic: InputOutput::RequireBriefOpen

package App::htmlgrep;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use AppBase::Grep;
use IPC::System::Options qw(system);
use Perinci::Sub::Util qw(gen_modified_sub);

our %SPEC;

sub _browser_dump {
    my ($input_path, $output_path, $args) = @_;

    if ($args->{browser} eq 'links') {
        system({shell=>1}, "links", "-force-html", "-dump", $input_path, \">", $output_path);
    } else {
        die "Browser not set or unknown";
    }
}

gen_modified_sub(
    output_name => 'htmlgrep',
    base_name   => 'AppBase::Grep::grep',
    summary     => 'Print lines matching text in HTML files',
    description => <<'_',

This is a wrapper for 'lynx -dump' (or equivalent in links and w3m) + grep-like
utility that is based on <pm:AppBase::Grep>. The unique features include
multiple patterns and `--dash-prefix-inverts`.

_
    add_args    => {
        files => {
            description => <<'_',

If not specified, will search for all HTML files recursively from the current
directory.

_
            'x.name.is_plural' => 1,
            'x.name.singular' => 'file',
            schema => ['array*', of=>'filename*'],
            pos => 1,
            slurpy => 1,
        },
        browser => {
            schema => ['str*', in=>[qw/lynx links w3m/]],
            default => 'links',
        },
        # XXX recursive (-r)
    },
    modify_meta => sub {
        my $meta = shift;
        $meta->{examples} = [
        ];
        $meta->{links} = [
        ];
        $meta->{deps} = {
        };
    },
    output_code => sub {
        my %args = @_;
        my ($tempdir, $fh, $file);

        my @files = @{ $args{files} // [] };
        if ($args{regexps} && @{ $args{regexps} }) {
            unshift @files, delete $args{pattern};
        }
        unless (@files) {
            require File::Find::Rule;
            @files = File::Find::Rule->new->file->name("*.htm", "*.html", "*.HTM", "*.HTML")->in(".");
            unless (@files) { return [200, "No HTML files to search against"] }
        }

        my $show_label = @files > 1 ? 1:0;

        $args{_source} = sub {
          READ_LINE:
            {
                if (!defined $fh) {
                    return unless @files;

                    unless (defined $tempdir) {
                        require File::Temp;
                        $tempdir = File::Temp::tempdir(CLEANUP=>$ENV{DEBUG} ? 0:1);
                    }

                    $file = shift @files;
                    require File::Basename;
                    my $tempfile = File::Basename::basename($file) . ".txt";
                    my $i = 0;
                    while (1) {
                        my $tempfile2 = $tempfile . ($i ? ".$i" : "");
                        do { $tempfile = $tempfile2; last } unless -e "$tempdir/$tempfile2";
                        $i++;
                    }

                    log_trace "Running browser dump $file $tempdir/$tempfile ...";
                    _browser_dump($file, "$tempdir/$tempfile", \%args);

                    open $fh, "<", "$tempdir/$tempfile" or do {
                        warn "htmlgrep: Can't open '$tempdir/$tempfile': $!, skipped\n";
                        undef $fh;
                    };
                    redo READ_LINE;
                }

                my $line = <$fh>;
                if (defined $line) {
                    return ($line, $show_label ? $file : undef);
                } else {
                    undef $fh;
                    redo READ_LINE;
                }
            }
        };

        AppBase::Grep::grep(%args);
    },
);

1;
# ABSTRACT:
