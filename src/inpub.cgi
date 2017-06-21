#!/usr/bin/perl

    use strict;
    use warnings;
    use lib qw(.);
    use Inpub;

# =================================================================

    # Mainline ----------------------------

    get_query_parameters();
    process_query();
    exit;
