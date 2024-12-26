# Webhook-Enabled Basic Heathcliff Announcement Machine

Perl script to announce when a new Heathcliff comic is available to read.

In theory, this can be used with any comic on the [Creators Syndicate] site.
This has not been tested.

[Creators Syndicate]: https://www.creators.com/categories/comics/all

## Requirements

Most dependencies are included in the default Perl distribution. For the sake
of completeness, all common modules used are as follows:

* Getopt::Long
* Pod::Usage
* LWP::UserAgent
* JSON
* File::Path

As far as modules you'll likely need to install via your distro's package
manager or CPAN:

* HTML::TreeBuilder::XPath

## Usage

```
    webham.pl [options] [webhook_url]

      Options:
        -h, --help      brief help message
        -v, --verbose   verbose output
        -c, --url       main comic url

Options:
    -h, --help
             Prints a brief help message and exits.

    -v, --verbose
             Prints information that may be useful for debugging.

    -c, --url
             Uses the given URL as the base. Primarily useful for other Comics Syndicate
             comics.
```

## License

BSD 3 Clause. See LICENSE.
