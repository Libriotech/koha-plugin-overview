package Koha::Plugin::No::Libriotech::Overview;

use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Auth;
use C4::Context;
our $dbh = C4::Context->dbh;

## Here we set our plugin version
our $VERSION = 0.02;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name   => 'Overview',
    author => 'Magnus Enger',
    description => 'Gives a statistical overview of your Koha instance.',
    date_authored   => '2017-05-25',
    date_updated    => '2017-05-25',
    minimum_version => '16.06.00.018',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    if ( $cgi->param('detail') ) {
        if ( $cgi->param('detail') eq 'items' ) {
            $self->items();
        }
    } else {
        # Default view
        $self->overview();
    }
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub overview {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'overview.tt' });

    $template->param(
        libraries => _count_table( 'branches' ),
        patrons   => _count_table( 'borrowers' ),
        records   => _count_table( 'biblio' ),
        items     => _count_table( 'items' ),
        issues    => _count_table( 'issues' ),
    );

    print $cgi->header();
    print $template->output();
}

sub items {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'items.tt' });

    $template->param(
        'itemtypes'     => _group_and_count( 'i.itype', 'it.description', 'items AS i', 'itemtypes AS it', 'i.itype = it.itemtype' ),
        'homebranch'    => _group_and_count( 'i.homebranch', 'b.branchname', 'items AS i', 'branches AS b', 'i.homebranch = b.branchcode' ),
        'holdingbranch' => _group_and_count( 'i.holdingbranch', 'b.branchname', 'items AS i', 'branches AS b', 'i.holdingbranch = b.branchcode' ),
    );

    print $cgi->header();
    print $template->output();
}

sub _group_and_count {

    my ( $alt, $name, $first, $second, $where ) = @_;

    my $query = "SELECT $alt AS alt, $name AS name, COUNT(*) AS count FROM $first, $second WHERE $where GROUP BY $alt";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $data = $sth->fetchall_arrayref({});

    return $data;

}

sub _count_table {

    my ( $table ) = @_;

    my $query = "SELECT COUNT(*) FROM $table";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my ($count) = $sth->fetchrow_array();

    return $count;

}

1;
