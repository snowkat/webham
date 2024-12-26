#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use 5.012;

use Getopt::Long qw(GetOptions);
use Pod::Usage;
use HTML::TreeBuilder::XPath;
use LWP::UserAgent;
use JSON;
use File::Path qw(make_path);

our $VERSION = "1.0";

sub get_cache_dir {
    use Env qw($XDG_STATE_HOME $HOME);

    my $cache_dir = $XDG_STATE_HOME;
    if (!length $cache_dir) {
        if (!length $HOME) {
            print STDERR "Hm. Couldn't get XDG_STATE_HOME or HOME, defaulting to /var/cache.";
            $cache_dir = "/var/cache";
        } else {
            $cache_dir = "$HOME/.local/state";
        }
    }

    "$cache_dir/heathcliff";
}

my $help = 0;
my $comic_url = "https://www.creators.com/read/heathcliff";
my $verbose = 0;

GetOptions(
    'help|h|?' => \$help,
    'c|url=s' => \$comic_url,
    'verbose|v' => \$verbose,
) or pod2usage(2);

pod2usage(1) if $help;

my $cache_dir = &get_cache_dir();
make_path($cache_dir);

# Get last URL we posted, if available
my $latest;
if ( -e "$cache_dir/latest" ) {
    open(my $fh, "<", "$cache_dir/latest")
        or warn "'$cache_dir/latest' exists but can't be opened: " . $!;
    chomp(my $content = <$fh>);
    $latest = $content;
    close($fh);
}

my $webhook_url = shift @ARGV
    or pod2usage({-msg => "Missing webhook URL.", -exitval => 2});

my $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:128.0) Gecko/20100101 WebHam/$VERSION");

print ">> GET $comic_url\n" if $verbose;
my $comic_html = $ua->get($comic_url);

if (not $comic_html->is_success) {
    die "Couldn't get today's comic. Response from server: ". $comic_html->status_line;
} elsif ($verbose) {
    print "Ok! Server said: " . $comic_html->status_line . "\n";
}

# og tags contain the secrets
# /head/meta[property="og:image"] is the comic
# /head/meta[property="og:title"] is "Heathcliff for [date], by [author]"
# /head/meta[property="og:url"] is a permaling to the URL
my $tree = HTML::TreeBuilder::XPath->new;
$tree->parse_content($comic_html->decoded_content)
    or die "Error parsing server response: " . $!;

my $metas = $tree->findnodes( '/html/head/meta[starts-with(@property,"og:")]' );
my %footer = (
    text=>"From Creators Syndicate",
);
my %embed = (
    type=>"rich",
    footer=>\%footer,
);
my %image_meta = ();
for my $og ($metas->get_nodelist) {
    my $prop = $og->attr('property');
    my $content = $og->attr('content');
    next if !defined($prop) or !defined($content);

    if ($prop eq "og:image") {
        $image_meta{url} = $content;
    } elsif ($prop eq "og:image:height") {
        # js strats - force perl to interpret this as an int
        $image_meta{height} = 0 + $content;
    } elsif ($prop eq "og:image:width") {
        # js strats - force perl to interpret this as an int
        $image_meta{width} = 0 + $content;
    } elsif ($prop eq "og:title") {
        if ($content =~ /(.+?), (by .+)/) {
            # split the title and author (looks better?)
            $embed{title} = $1;
            $embed{description} = $2;
        } else {
            # must have changed. oh well
            $embed{title} = $content;
        }
    } elsif ($prop eq "og:url") {
        # Check if we've already gotten this one
        if (defined $latest && $latest eq $content) {
            print "Already posted $content, bailing out.\n" if $verbose;
            exit 0;
        }
        $embed{url} = $content;
    }
}

$embed{image} = \%image_meta;
my @embeds = ( \%embed );

my %payload = (
    embeds=>\@embeds,
);

my $content = encode_json \%payload;

print ">> POST $webhook_url\n" if $verbose;

my $wh_req = HTTP::Request->new(POST => $webhook_url);
$wh_req->content_type('application/json');
$wh_req->content($content);

my $res = $ua->request($wh_req);
if (! $res->is_success) {
    die $res->content;
} else {
    print "Sent!\n" if $verbose;
    open(my $fh, ">", "$cache_dir/latest")
        or die "Sent webhook, but couldn't open '$cache_dir/latest' for writing: " . $!;
    print $fh $embed{url};
}

__END__

=head1 NAME

webham.pl - Heathcliff webhook for Discord

=head1 SYNOPSIS

webham.pl [options] [webhook_url]

  Options:
    -h, --help      brief help message
    -v, --verbose   verbose output
    -c, --url       main comic url


=head1 OPTIONS

=over 8

=item B<-h, --help>

 Prints a brief help message and exits.

=item B<-v, --verbose>

 Prints information that may be useful for debugging.

=item B<-c, --url>

 Uses the given URL as the base. Primarily useful for other Comics Syndicate
 comics.

=back

=head1 DESCRIPTION

B<webham> loads the latest Heathcliff comic and, if it's been updated since
last checked, executes the given Discord webhook.


=cut
