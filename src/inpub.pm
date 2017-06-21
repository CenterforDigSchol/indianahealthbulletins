#! Inpub.pm

    package Inpub;
    require Exporter;
    our @ISA    = qw(Exporter);
    our @EXPORT = qw(get_query_parameters process_query download_csv);

    use strict;
    use warnings;
    use DBI;
    use CGI qw(:standard);
    use CGI::Carp qw(fatalsToBrowser);

# Subroutine prototypes ------------------------------------

    # Query parameters
    sub get_query_parameters();
    sub get_query_type();
    sub get_output_layout();
    sub get_query_months();
    sub get_query_regions();
    sub get_query_statistics();
    sub validate_output_layout($);
    sub validate_month($);
    sub validate_year($);
    sub validate_region($);
    sub validate_statistic($);
    sub query_input_error($);

    # Query
    sub process_query();
    sub process_query_with_mrs_layout();
    sub process_query_with_msr_layout();
    sub process_query_with_rms_layout();
    sub process_query_with_rsm_layout();
    sub process_query_with_smr_layout();
    sub process_query_with_srm_layout();

    sub get_population($$$);

    # Display
    sub display_results($$$);
    sub display_inpub_header($);
    sub display_inpub_footer();
    sub display_table($$);
    sub continue_query_form();
    sub continue_query_by_month();
    sub continue_query_by_region();
    sub continue_query_by_statistic();
    sub continue_query_html(@); # Note: Parameter is a hash
    sub display_additional_query_options();
    sub save_query_state();
    sub query_state_string();

    sub download_csv();

    # Utilities
    sub inpub_connect($);
    sub months_equal($$);
    sub next_month($$);
    sub death_rate($$);
    sub convert_to_spreadsheet(@);

    # Unit testing
    sub setup_unit_test($);
    sub setup_unit_test_select_all($);

# Constants -----------------------------------------------

    # CGI directory
    my $CGI_BIN = 'http://inpub.medicine.iu.edu/cgi-bin';

    # Web directory
    my $WEB_ROOT = 'http://inpub.medicine.iu.edu';

    # Local web directory
    my $LOCAL_WEB_ROOT = '/Volumes/Data/inpub';

    # Data not available
    my $DATA_NOT_AVAILABLE = '...';

# Global tables -------------------------------------------

    # Output layouts for the results.
    my @output_layout_options = (
        "mrs",  # One table per Month, Regions in rows, Statistics in columns
        "msr",  # One table per Month, Statistics in rows, Regions in columns
        "rms",  # One table per Region, Months in rows, Statistics in columns
        "rsm",  # One table per Region, Statistics in rows, Months in columns
        "smr",  # One table per Statistic, Months in rows, Regions in columns
        "srm",  # One table per Statistic, Regions in rows, Months in columns
    );

    # Map month from string value to numeric value.
    my %month_as_number = (
        "January"   => 1,
        "February"  => 2,
        "March"     => 3,
        "April"     => 4,
        "May"       => 5,
        "June"      => 6,
        "July"      => 7,
        "August"    => 8,
        "September" => 9,
        "October"   => 10,
        "November"  => 11,
        "December"  => 12
    );

    # Map month numeric value to string value (for display purposes).
    my @month_as_string = (
        "",
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
    );

    # Map Region name to Region label
    my %regionName_to_regionLabel = (
        "indiana"           =>  "Indiana (statewide)",
        "northern_counties" =>  "Northern counties",
        "central_counties"  =>  "Central counties",
        "southern_counties" =>  "Southern counties",
        "urban"             =>  "Urban",
        "rural"             =>  "Rural",
        "class_1_cities"    =>  "Cities, class 1",
        "class_2_cities"    =>  "Cities, class 2",
        "class_3_cities"    =>  "Cities, class 3",
        "class_4_cities"    =>  "Cities, class 4",
        "class_5_cities"    =>  "Cities, class 5",
    );

    # Map Statistic name to Statistic label
    my %statisticName_to_statisticLabel = (
        "population"             => "Population",
        "births"                 => "Births",
        "total_deaths"           => "Total Deaths",
        "tuberculosis"           => "Tuberculosis",
        "pulmonary_tuberculosis" => "Pulmonary Tuberculosis",
        "other_tuberculosis"     => "Other Forms, Tuberculosis",
        "typhoid"                => "Typhoid Fever",
        "diptheria_and_croup"    => "Diptheria and Croup",
        "diptheria"              => "Diptheria",
        "croup"                  => "Croup",
        "scarlet_fever"          => "Scarlet Fever",
        "measles"                => "Measles",
        "whooping_cough"         => "Whooping Cough",
        "pneumonia"              => "Pneumonia",
        "diarrhea_and_enteritis" => "Diarrhea and Enteritis, Under 2 Years",
        "diarrhea_under_five"    => "Diarrheal Diseases, Under 5 Years",
        "cerebro_spinal_fever"   => "Meningitis",
        "polio"                  => "Poliomyelitis",
        "influenza"              => "Influenza",
        "septicemia"             => "Puerperal",
        "cancer"                 => "Cancer",
        "external_causes"        => "External Causes",
        "violence"               => "Violence",
        "accidental"             => "Accidental",
        "suicide"                => "Suicide",
        "homicidal"              => "Homicidal",
        "smallpox"               => "Smallpox",
        "syphilis"               => "Syphilis",
        "heart_disease"          => "Heart Disease",
        "apoplexy"               => "Apoplexy",
        "brights_disease"        => "Bright's Disease",
        "diabetes"               => "Diabetes",
        "goiter"                 => "Goiter",
    );

# Pre-built query lists  ------------------------------------

    # All regions
    my @all_regions = (
        "indiana",
        "northern_counties",
        "central_counties",
        "southern_counties",
        "urban",
        "rural",
        "class_1_cities",
        "class_2_cities",
        "class_3_cities",
        "class_4_cities",
        "class_5_cities"
    );

    # All statistics
    my @all_statistics = (
        "population",
        "births",
        "total_deaths",
        "tuberculosis",
        "pulmonary_tuberculosis",
        "other_tuberculosis",
        "typhoid",
        "diptheria_and_croup",
        "diptheria",
        "croup",
        "scarlet_fever",
        "measles",
        "whooping_cough",
        "pneumonia",
        "diarrhea_and_enteritis",
        "diarrhea_under_five",
        "cerebro_spinal_fever",
        "polio",
        "influenza",
        "septicemia",
        "cancer",
        "external_causes",
        "violence",
        "accidental",
        "suicide",
        "homicidal",
        "smallpox",
        "syphilis",
        "heart_disease",
        "apoplexy",
        "brights_disease",
        "diabetes",
        "goiter"
    );

# Global variables ------------------------------------------

    # CGI object
    my $pCGI;

    # Database handle
    my $dbh;

    # Query input ------------------------------

    # query_type: Indicates the query type.
    # Valid values: "new_query" or "continue_query"
    my $query_type = "";

    # output_layout: Indicates the layout option for the results.
    # Valid values: See @output_layout_options.
    my $output_layout = "";

    # query_months: An array of hashes for each query month.
    # Hash keys: sql_month, sql_year
    my @query_months = ();

    # query_regions: An array of region names.
    my @query_regions = ();

    # query_statistics: An array of statistic names.
    my @query_statistics = ();

    # Current query selection, for continuing query.
    my ($current_month, $current_year, $current_region, $current_statistic);

# =================================================================

# Get user query parameters for query type, months, regions, and statistics.
# Save in global variables:
#   $query_type, $output_layout,
#   @query_months, @query_regions, @query_statistics.
#   $current_month, $current_year, $current_region, $current_statistic

sub get_query_parameters() {

    # Initialize CGI object.
    $pCGI = new CGI;

    # Clear the PATH variable, for Taint mode.
    $ENV{'PATH'} = '';

    # Get the query parameters via CGI.
    get_query_type();
    get_output_layout();
    get_query_months();
    get_query_regions();
    get_query_statistics();

    return 1;
}


# Get query type ("new_query" or "continue_query"),
# and save in global variable $query_type.

sub get_query_type() {
    if ($pCGI->param("query_new_table")) {
        # Continuing query, submitted from the continue query form
        # on the query results page.
        $query_type = "continue_query";
    }
    else {
        # New query, submitted from the new query form.
        $query_type = "new_query";
    }
}


# Get the layout option for the results,
# and save in global variable $output_layout.

sub get_output_layout() {
    $pCGI->param("output_layout") =~ /^(\w+)$/;
    $output_layout = $1;
    validate_output_layout($output_layout);
}


# Get list of query months, and save in global variable @query_months.

sub get_query_months() {

    # Reset @query_months.
    @query_months = ();

    # Starting month/year
    $pCGI->param("starting_month") =~ /^(\w+)$/;
    my $starting_month_param = $1;
    validate_month($starting_month_param);
    $pCGI->param("starting_year") =~ /^(\d+)$/;
    my $starting_year_param = $1;
    validate_year($starting_year_param);

    my $starting_month = {};
    $starting_month->{sql_month} = $starting_month_param;
    $starting_month->{sql_year} = $starting_year_param;
    $query_months[0] = $starting_month;

    # Ending month/year
    $pCGI->param("ending_month") =~ /^(\w+)$/;
    my $ending_month_param = $1;
    validate_month($ending_month_param);
    $pCGI->param("ending_year") =~ /^(\d+)$/;
    my $ending_year_param = $1;
    validate_year($ending_year_param);

    my $ending_month = {};
    $ending_month->{sql_month} = $ending_month_param;
    $ending_month->{sql_year} = $ending_year_param;

    # Determine the direction of the time range.
    # If the ending month/year is before the starting month/year,
    # then set the time direction to "reverse".
    my $time_direction = "forward";
    if ($starting_month->{sql_year} > $ending_month->{sql_year}) {
        $time_direction = "reverse";
    }
    if (($starting_month->{sql_year} == $ending_month->{sql_year}) &&
        ($starting_month->{sql_month} > $ending_month->{sql_month}))
    {
        $time_direction = "reverse";
    }

    # Calculate the remaining months in the time range.
    my $month = $starting_month;
    while (!months_equal($month, $ending_month)) {
        $month = next_month($time_direction, $month);
        push @query_months, $month;
    }

    # Initialize the current month and year to the starting month and year
    # for this query.
    $current_month = $query_months[0]->{sql_month};
    $current_year  = $query_months[0]->{sql_year};

    # If the user selected a new month/year from the menu,
    # then set $current_month and $current_year to the new values.
    # Note: This applies to the "mrs" and "msr" output layouts only.
    if ($pCGI->param("new_month")) {
        $pCGI->param("new_month") =~ /^(\d+) (\d+)$/;
        $current_month = $1;
        $current_year = $2;

        validate_month($current_month);
        validate_year($current_year);
    }

}


# Get list of query regions, and save in global variable @query_regions.

sub get_query_regions() {

    # Reset @query_regions.
    @query_regions = ();

    foreach my $region_param ($pCGI->param("region")) {
        $region_param =~ /^(\w+)$/;
        my $region = $1;
        validate_region($region);
        push @query_regions, $region;
    };

    # If no regions were selected, then select ALL regions.
    if (scalar(@query_regions) == 0) {
        @query_regions = @all_regions;
    }

    # Initialize the current region to the first region for this query.
    $current_region = $query_regions[0];

    # If the user selected a new region from the menu,
    # then set $current_region to the new value.
    # Note: This applies to the "rms" and "rsm" output layouts only.
    if ($pCGI->param("new_region")) {
        $pCGI->param("new_region") =~ /^(\w+)$/;
        $current_region = $1;
        validate_region($current_region);
    }
}


# Get list of query statistics, and save in global variable @query_statistics.

sub get_query_statistics() {

    # Reset @query_statistics.
    @query_statistics = ();

    foreach my $statistic_param ($pCGI->param("statistic")) {
        $statistic_param =~ /^(\w+)$/;
        my $statistic = $1;
        validate_statistic($statistic);
        push @query_statistics, $statistic;
    };

    # If no statistics were selected, then select ALL statistics.
    if (scalar(@query_statistics) == 0) {
        @query_statistics = @all_statistics;
    }

    # Initialize the current statistic to the first statistic for this query.
    $current_statistic = $query_statistics[0];

    # If the user selected a new statistic from the menu,
    # then set $current_statistic to the new value.
    # Note: This applies to the "smr" and "srm" output layouts only.
    if ($pCGI->param("new_statistic")) {
        $pCGI->param("new_statistic") =~ /^(\w+)$/;
        $current_statistic = $1;
        validate_statistic($current_statistic);
    }
}

# =================================================================

# Validate the layout option for the results.
#
# Parameters:
#   $output_layout: Output layout option, to be validated

sub validate_output_layout($) {
    my $output_layout = shift;
    my $result = 0;

    foreach my $valid_output_layout (@output_layout_options) {
        if ($output_layout eq $valid_output_layout) {
            $result = 1;
        }
    }

    if (!$result) {
        query_input_error("Invalid output layout: ${output_layout}");
    }

    return $result;
}

# Validate the query month.
#
# Parameters:
#   $month: Month, to be validated

sub validate_month($) {
    my $month = shift;
    my $result = 0;

    if (($month < 1) || ($month > 12)) {
        query_input_error("Invalid month: ${month}");
    }
    else {
        $result = 1;
    }

    return $result;
}

# Validate the query year.
# Note: Accepting years in range 1899-1989, to allow for future expansion.
#
# Parameters:
#   $year: Year, to be validated

sub validate_year($) {
    my $year = shift;
    my $result = 0;

    if (($year < 1899) || ($year > 1989)) {
        query_input_error("Invalid year: ${year}");
    }
    else {
        $result = 1;
    }

    return $result;
}

# Validate the query region.
#
# Parameters:
#   $region: Year, to be validated

sub validate_region($) {
    my $region = shift;
    my $result = 0;

    foreach my $valid_region (keys %regionName_to_regionLabel) {
        if ($region eq $valid_region) {
            $result = 1;
        }
    }

    if (!$result) {
        query_input_error("Invalid region: ${region}");
    }

    return $result;
}

# Validate the query statistic.
#
# Parameters:
#   $statistic: statistic name

sub validate_statistic($) {
    my $statistic = shift;
    my $result = 0;

    foreach my $valid_statistic (keys %statisticName_to_statisticLabel) {
        if ($statistic eq $valid_statistic) {
            $result = 1;
        }
    }

    if (!$result) {
        query_input_error("Invalid statistic: ${statistic}");
    }

    return $result;
}

# Display error message for query input error.
#
# Parameters:
#   $error_string: Error string to be displayed

sub query_input_error($) {
    my $error_string = shift;

    print
        header(),
        start_html('Query input error'),
        h1('Query input error'),
        hr(),
        strong(${error_string}),
        end_html();

    exit;
}

# =================================================================

# Query the database, and display the results in the specified layout.

sub process_query() {

    # Connect to the INPUB database.
    $dbh = inpub_connect('inpub');

    if    ($output_layout eq "mrs") { process_query_with_mrs_layout(); }
    elsif ($output_layout eq "msr") { process_query_with_msr_layout(); }
    elsif ($output_layout eq "rms") { process_query_with_rms_layout(); }
    elsif ($output_layout eq "rsm") { process_query_with_rsm_layout(); }
    elsif ($output_layout eq "smr") { process_query_with_smr_layout(); }
    elsif ($output_layout eq "srm") { process_query_with_srm_layout(); }

    # Disconnect from the database.
    $dbh->disconnect()
        or warn "Disconnection failed: $DBI::errstr\n";

    return 1;
}


# Query the database, and display the results in the following layout:
#   One table per Month, Regions in rows, Statistics in columns.
 
sub process_query_with_mrs_layout() {

    # Table caption.
    my $table_caption = $month_as_string[$current_month];
    $table_caption .= " ${current_year}";

    # Table column headings.
    my @column_headings = ("Region");
    foreach my $statistic_name (@query_statistics) {
        my $column_heading_label =
            $statisticName_to_statisticLabel{$statistic_name};
        push @column_headings, $column_heading_label;
    }

    # Table rows.
    my @death_number_table = ( \@column_headings );
    my @death_rate_table = ( \@column_headings );

    # SQL SELECT statement:
    #   SELECT region, <statistic_1>, ..., <statistic_n>
    #   FROM mortality
    #   WHERE month = ? AND year = ? AND region = ?

    my $sth = $dbh->prepare(
        "SELECT region, " .
        join(', ', @query_statistics) . ' ' .
        "FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    # Get the statistic values from the database,
    # and build the table data rows.

    foreach my $region (@query_regions) {

        # Execute the query.
        $sth->bind_param(1, $current_month);
        $sth->bind_param(2, $current_year);
        $sth->bind_param(3, $region);
        $sth->execute();

        # Get the population for this month and region.
        my $population = get_population($current_month, $current_year, $region);

        # Set the row header in the tables.
        my $row_header = $regionName_to_regionLabel{$region};
        my @death_number_row = ( $row_header );
        my @death_rate_row = ( $row_header );

        # Fetch record, and set statistics values in the tables.
        my $pRecord = $sth->fetchrow_hashref();
        foreach my $statistic_name (@query_statistics) {
            my $statistic_value = $pRecord->{$statistic_name};
            push @death_number_row, $statistic_value;
            push @death_rate_row, death_rate($population, $statistic_value);
        }

        push @death_number_table, \@death_number_row;
        push @death_rate_table, \@death_rate_row;
    }

    # Display the query results in a web page.
    display_results(
        $table_caption,
        \@death_number_table,
        \@death_rate_table
    );

}

# Query the database, and display the results in the following layout:
#   One table per Month, Statistics in rows, Regions in columns.
#
# @death_number_table and @death_rate_table are indexed by
# [$statistic_ix, $region_ix]
 
sub process_query_with_msr_layout() {

    # Table caption.
    my $table_caption = $month_as_string[$current_month];
    $table_caption .= " ${current_year}";

    # Table column headings.
    my @column_headings = ( "Statistic" );
    foreach my $region_name (@query_regions) {
        my $column_heading_label = $regionName_to_regionLabel{$region_name};
        push @column_headings, $column_heading_label;
    }

    # Table rows.
    my @death_number_table = ( \@column_headings );
    my @death_rate_table = ( \@column_headings );

    # Row headings (statistic labels).
    foreach my $statistic_name (@query_statistics) {
        my $statistic_label =
            $statisticName_to_statisticLabel{$statistic_name};
        my @death_number_row = ( $statistic_label );
        push @death_number_table, \@death_number_row;
        my @death_rate_row = ( $statistic_label );
        push @death_rate_table, \@death_rate_row;
    }

    # SQL SELECT statement:
    #   SELECT region, <statistic_1>, ..., <statistic_n>
    #   FROM mortality
    #   WHERE month = ? AND year = ? AND region = ?

    my $sth = $dbh->prepare(
        "SELECT region, " .
        join(', ', @query_statistics) . ' ' .
        "FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    # Get the statistic values from the database,
    # and build the table data rows.
    my $region_ix = 1;
    foreach my $region (@query_regions) {

        # Execute the query.
        $sth->bind_param(1, $current_month);
        $sth->bind_param(2, $current_year);
        $sth->bind_param(3, $region);
        $sth->execute();

        # Get the population for this month and region.
        my $population = get_population($current_month, $current_year, $region);

        # Fetch record, and copy the statistic values to the table data row.
        my $pRecord = $sth->fetchrow_hashref();
        my $statistic_ix = 1;
        foreach my $statistic_name (@query_statistics) {
            my $statistic_value = $pRecord->{$statistic_name};
            $death_number_table[$statistic_ix]->[$region_ix] = $statistic_value;
            $death_rate_table[$statistic_ix]->[$region_ix] =
                death_rate($population, $statistic_value);
            $statistic_ix++;
        }

        $region_ix++;
    }

    # Display the query results in a web page.
    display_results(
        $table_caption,
        \@death_number_table,
        \@death_rate_table
    );

}


# Query the database, and display the results in the following layout:
#   One table per Region, Months in rows, Statistics in columns.
 
sub process_query_with_rms_layout() {

    # Table caption.
    my $table_caption = $regionName_to_regionLabel{$current_region};

    # Table column headings.
    my @column_headings = ("Month and Year");
    foreach my $statistic_name (@query_statistics) {
        my $column_heading_label =
            $statisticName_to_statisticLabel{$statistic_name};
        push @column_headings, $column_heading_label;
    }

    # Table rows.
    my @death_number_table = ( \@column_headings );
    my @death_rate_table = ( \@column_headings );

    # SQL SELECT statement:
    #   SELECT month, year, <statistic_1>, ..., <statistic_n>
    #   FROM mortality
    #   WHERE region = ? AND month = ? AND year = ?

    my $sth = $dbh->prepare(
        "SELECT month, year, " .
        join(', ', @query_statistics) . ' ' .
        "FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    # Get the statistic values from the database,
    # and build the table data rows.

    foreach my $month (@query_months) {

        # Execute the query.
        $sth->bind_param(1, $month->{sql_month});
        $sth->bind_param(2, $month->{sql_year});
        $sth->bind_param(3, $current_region);
        $sth->execute();

        # Get the population for this month and region.
        my $population = get_population(
            $month->{sql_month}, $month->{sql_year}, $current_region);

        # Row header.
        my $row_header = $month_as_string[$month->{sql_month}];
        $row_header .= ' ';
        $row_header .= $month->{sql_year};
        my @death_number_row = ( $row_header );
        my @death_rate_row = ( $row_header );

        # Data fields.
        my $pRecord = $sth->fetchrow_hashref();
        foreach my $statistic_name (@query_statistics) {
            my $statistic_value = $pRecord->{$statistic_name};
            push @death_number_row, $statistic_value;
            push @death_rate_row, death_rate($population, $statistic_value);
        }

        push @death_number_table, \@death_number_row;
        push @death_rate_table, \@death_rate_row;
    }

    # Display the query results in a web page.
    display_results(
        $table_caption,
        \@death_number_table,
        \@death_rate_table
    );

}


# Query the database, and display the results in the following layout:
#   One table per Region, Statistics in rows, Months in columns.
#
# @death_number_table and @death_rate_table are indexed by
# [$statistic_ix, $region_ix]
 
sub process_query_with_rsm_layout() {

    # Table caption.
    my $table_caption = $regionName_to_regionLabel{$current_region};

    # Table column headings.
    my @column_headings = ( "Statistic" );
    foreach my $month_year (@query_months) {
        my $column_heading_label = $month_as_string[$month_year->{sql_month}];
        $column_heading_label .= ' ';
        $column_heading_label .= $month_year->{sql_year};
        push @column_headings, $column_heading_label;
    }

    # Table rows.
    my @death_number_table = ( \@column_headings );
    my @death_rate_table =   ( \@column_headings );

    # Row headings (statistic labels).
    foreach my $statistic_name (@query_statistics) {
        my $statistic_label =
            $statisticName_to_statisticLabel{$statistic_name};
        my @death_number_row = ( $statistic_label );
        push @death_number_table, \@death_number_row;
        my @death_rate_row = ( $statistic_label );
        push @death_rate_table, \@death_rate_row;
    }

    # SQL SELECT statement:
    #   SELECT month, year, <statistic_1>, ..., <statistic_n>
    #   FROM mortality
    #   WHERE region = ? AND month = ? AND year = ?

    my $sth = $dbh->prepare(
        "SELECT month, year, " .
        join(', ', @query_statistics) . ' ' .
        "FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    # Get the statistic values from the database,
    # and build the table data rows.
    my $month_ix = 1;
    foreach my $month (@query_months) {

        # Execute the query.
        $sth->bind_param(1, $month->{sql_month});
        $sth->bind_param(2, $month->{sql_year});
        $sth->bind_param(3, $current_region);
        $sth->execute();

        # Get the population for this month and region.
        my $population = get_population(
            $month->{sql_month}, $month->{sql_year}, $current_region);

        # Fetch record, and copy the statistic values to the table data row.
        my $pRecord = $sth->fetchrow_hashref();
        my $statistic_ix = 1;
        foreach my $statistic_name (@query_statistics) {
            my $statistic_value = $pRecord->{$statistic_name};
            $death_number_table[$statistic_ix]->[$month_ix] =
                $statistic_value;
            $death_rate_table[$statistic_ix]->[$month_ix] =
                death_rate($population, $statistic_value);
            $statistic_ix++;
        }

        $month_ix++;
    }

    # Display the query results in a web page.
    display_results(
        $table_caption,
        \@death_number_table,
        \@death_rate_table
    );

}


# Query the database, and display the results in the following layout:
#   One table per Statistic, Months in rows, Regions in columns.
 
sub process_query_with_smr_layout() {

    # Table caption.
    my $table_caption = $statisticName_to_statisticLabel{$current_statistic};

    # Table column headings.
    my @column_headings = ("Month and Year");
    foreach my $region_name (@query_regions) {
        my $column_heading_label = $regionName_to_regionLabel{$region_name};
        push @column_headings, $column_heading_label;
    }

    # Table rows.
    my @death_number_table = ( \@column_headings );
    my @death_rate_table   = ( \@column_headings );

    # SQL SELECT statement:
    #   SELECT month, year, region, <current_statistic>
    #   FROM mortality
    #   WHERE month = ? AND year = ? AND region = ?

    my $sth = $dbh->prepare(
        "SELECT month, year, region, ${current_statistic} " .
        "FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    # Get the statistic values from the database,
    # and build the table data rows.
    foreach my $month (@query_months) {

        # Row header.
        my $row_header = $month_as_string[$month->{sql_month}];
        $row_header .= ' ';
        $row_header .= $month->{sql_year};
        my @death_number_row = ( $row_header );
        my @death_rate_row = ( $row_header );

        # Get the statistic value for each region.
        foreach my $region (@query_regions) {

            # Execute the query.
            $sth->bind_param(1, $month->{sql_month});
            $sth->bind_param(2, $month->{sql_year});
            $sth->bind_param(3, $region);
            $sth->execute();

            # Get the population for this month and region.
            my $population = get_population(
                $month->{sql_month}, $month->{sql_year}, $region);

            # Fetch record, and copy the statistic value (for this region)
            # to the table data row.
            my $pRecord = $sth->fetchrow_hashref();
            my $statistic_value = $pRecord->{$current_statistic};
            push @death_number_row, $statistic_value;
            push @death_rate_row, death_rate($population, $statistic_value);
        }

        push @death_number_table, \@death_number_row;
        push @death_rate_table, \@death_rate_row;

    }

    # Display the query results in a web page.
    display_results(
        $table_caption,
        \@death_number_table,
        \@death_rate_table
    );

}


# Query the database, and display the results in the following layout:
#   One table per Statistic, Regions in rows, Months in columns.
 
sub process_query_with_srm_layout() {

    # Table caption.
    my $table_caption = $statisticName_to_statisticLabel{$current_statistic};

    # Table column headings.
    my @column_headings = ("Region");
    foreach my $month_year (@query_months) {
        my $column_heading_label = $month_as_string[$month_year->{sql_month}];
        $column_heading_label .= ' ';
        $column_heading_label .= $month_year->{sql_year};
        push @column_headings, $column_heading_label;
    }

    # Table rows.
    my @death_number_table = ( \@column_headings );
    my @death_rate_table   = ( \@column_headings );

    # SQL SELECT statement:
    #   SELECT month, year, region, <current_statistic>
    #   FROM mortality
    #   WHERE month = ? AND year = ? AND region = ?

    my $sth = $dbh->prepare(
        "SELECT month, year, region, ${current_statistic} " .
        "FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    # Get the statistic values from the database,
    # and build the table data rows.
    foreach my $region (@query_regions) {

        # Row header.
        my $row_header = $regionName_to_regionLabel{$region};
        my @death_number_row = ( $row_header );
        my @death_rate_row =   ( $row_header );

        # Get the statistic value for each month.
        foreach my $month (@query_months) {

            # Execute the query.
            $sth->bind_param(1, $month->{sql_month});
            $sth->bind_param(2, $month->{sql_year});
            $sth->bind_param(3, $region);
            $sth->execute();

            # Get the population for this month and region.
            my $population = get_population(
                $month->{sql_month}, $month->{sql_year}, $region);

            # Fetch record, and copy the statistic value (for this month)
            # to the table data row.
            my $pRecord = $sth->fetchrow_hashref();
            my $statistic_value = $pRecord->{$current_statistic};
            push @death_number_row, $statistic_value;
            push @death_rate_row, death_rate($population, $statistic_value);
        }

        push @death_number_table, \@death_number_row;
        push @death_rate_table,   \@death_rate_row;

    }

    # Display the query results in a web page.
    display_results(
        $table_caption,
        \@death_number_table,
        \@death_rate_table
    );

}


# Gets the population statistic for the specified month, year, and region.
#
# Parameters:
#   $month:     Month
#   $year:      Year
#   $region:    Region

sub get_population($$$) {

    # Parameters.
    my $month = shift;
    my $year = shift;
    my $region = shift;

    # SQL SELECT statement:
    #   SELECT population FROM mortality
    #   WHERE month = ? AND year = ? AND region = ?

    my $sth = $dbh->prepare(
        "SELECT population FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    # Execute population query.
    $sth->bind_param(1, $month);
    $sth->bind_param(2, $year);
    $sth->bind_param(3, $region);
    $sth->execute();

    # Fetch the population query results.
    my @population_query_data = $sth->fetchrow_array();

    # Return the population.
    return $population_query_data[0];
}

# =================================================================

# Display the query results in a web page.
#
# Parameters:
#   $table_caption:         Table caption
#   $death_number_table:    Death Number table,
#                           reference to array of array references
#   $death_rate_table:      Death Rate table,
#                           reference to array of array references

sub display_results($$$) {

    # Parameters.
    my $table_caption = shift;
    my $pDeathNumberTable = shift;
    my $pDeathRateTable = shift;

    # Display the HTTP header.
    print header();

    # INPUB header (for branding)
    display_inpub_header('INPUB database query results');

    # Section header: Query results
    print qq(<h2> Query results </h2>\n\n);

    # Display form to continue the query.
    continue_query_form();

    # Death Number table
    my $caption = $table_caption;
    unless ( $table_caption =~ m/Population/ ) {
        $caption .= ': Number of deaths';
    }

    display_table(
        $caption,
        $pDeathNumberTable);

    # Explanatory text for the Death Number table.
    print "<p>\n";
    print <<"    HTML";
        <em>Each number in the above table represents the number of deaths from
        the specified cause by month and geographical region, as reported in
        the Monthly Bulletin of the Indiana State Board of Health.
        This mortality data does not include stillbirths.
        All geographical regions are in the state of Indiana.</em>
    HTML
    print "</p>\n\n";

    unless ( $table_caption =~ m/Population/ ) {
        # Death Rate table
        display_table(
            $table_caption . ': Death rate (per 100,000)',
            $pDeathRateTable);

        # Explanatory text for the Death Rate table.
        print "<p>\n";
        print <<"        HTML";
            <em>Each number in the above table represents the death rate
            from the specified cause by month and geographical region.
            The death rate is calculated per 100,000 population,
            on a monthly basis.</em>
        HTML
        print "</p>\n\n";
    }

    # Separator.
    print qq(<hr />\n\n);

    # Section header: Additional query options
    print qq(<h2> Additional query options </h2>\n);

    # Display additional query options
    display_additional_query_options();

    # INPUB footer (for branding)
    display_inpub_footer();

    # Display the web page footer.
    print end_html();
}

# Display the INPUB header (for branding).
#
# Parameters:
#   $title: Web page title

sub display_inpub_header($) {

    # Parameters.
    my $title = shift;

    print qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    );

    print <<"    END_HTML";
        <html xmlns="http://www.w3.org/1999/xhtml">

        <head>
            <title> ${title} </title>

            <meta name="Keywords"
            content="IU, Indiana University,
            Indiana Public Health Mortality Database,
            Indiana State Library, Ruth Lilly Medical Library" />

            <meta name="Description"
            content="INPUB mortality database query results />

            <meta http-equiv="Content-Type"
            content="text/html; charset=iso-8859-1" />

            <!-- INDIANA PUBLIC HEALTH DIGITAL LIBRARY style sheet -->
            <link rel="stylesheet" type="text/css"
            href="${WEB_ROOT}/css/inpub-style.css" />

            <!-- INPUB database style sheet -->
            <link rel="stylesheet" type="text/css"
            href="${WEB_ROOT}/database/inpub_db.css" />

            <!-- ADDING VERT MENU CODE FOR HEADER HERE -->
        <!--[if lte IE 6]>  
        <link rel="stylesheet" href="${WEB_ROOT}/css/hack.css">  <script type="text/javascript">  window.mlrunShim = true; </script> 
        <![endif]-->
        <script type="text/javascript" src="${WEB_ROOT}/js.js"> //This script Copyright Brady Mulhollem - WebTech101.com //This notice must stay intact for legal use </script> 

        </head>

        <body>

        <!-- BEGIN INDIANA PUBLIC HEALTH DIGITAL LIBRARY IDENTITY CONTENT -->
        <div id="identity">

            <!-- INSERT INDIANA PUBLIC HEALTH DIGITAL LIBRARY LOGO -->
            <a href="${WEB_ROOT}/index.shtml">
            <img src="${WEB_ROOT}/img/inpub-logo.gif"
            alt="Indiana Public Health Digital Library logo" /> </a>

        </div>
        <!-- END INDIANA PUBLIC HEALTH DIGITAL LIBRARY IDENTITY -->

<!--BEGIN TOP NAVIGATION BAR -->
        <!--[if IE]> <div id="IE"> <![endif]-->
		<div id="mainNav">  
        <ul>
            <li><a class="other" href="../public.shtml">For Indiana residents</a></li>
            <li><a class="other" href="../historians.shtml">For historians</a></li>
            <li><a class="other" href="../publichealth.shtml">For public health professionals</a></li>
        </ul>
        
        </div>      <!--END TOP NAVIGATION BAR -->
        <!--[if IE]> </div> <![endif]-->

    <!-- BEGIN LEFT (TERTIARY) NAVIGATION BAR FOR INDIANA PUBLIC HEALTH DIGITAL LIBRARY -->
    <!-- ADDING VERT NAV CODE HERE -->
    <!--[if IE]> <div id="IE"> <![endif]-->
        <div id="secondaryNav">
        <div class="mlmenu vertical arrow delay accessible trail"> 
        <ul>  
        <li><a href="http://cdm1819-01.cdmhost.com/cdm4/browse.php?CISOROOT=%2Fp1819coll12">Indiana State Board of Health Monthly Bulletin (1899 - )</a>
            <ul>
            <li>
                <form method="GET" action="http://cdm1819-01.cdmhost.com/cdm4/results.php">
                <input type="hidden" name="CISOOP1" value="all">
                <input type="hidden" name="CISOFIELD1" value="subjec">
                <input type="hidden" name="CISORESTMP" value="results.php">
                <input type="hidden" name="CISOVIEWTMP" value="item_viewer.php">
                <input type="hidden" name="CISOMODE" value="bib">
                <input type="hidden" name="CISOGRID" value=         "thumbnail,A,1;title,A,1;subjec,A,0;descri,200,0;none,A,0;20;title,none,none,none,none">
                <input type="hidden" name="CISOBIB" value="covera,A,0,N;title,A,1,N;descri,A,0,N;none,A,0,N;none,A,0,N;20;covera,none,none,none,none">
                <input type="hidden" name="CISOTHUMB" value="20 (4x5);title,none,none,none,none">
                <input type="hidden" name="CISOTITLE" value="20;title,none,none,none,none">
                <input type="hidden" name="CISOHIERA" value="20;subjec,title,none,none,none">
                <input type="hidden" name="CISOSUPPRESS" value="0">
                
                <input type="hidden" name="CISOROOT" value="/p1819coll12">
                <input type="text" title="Search" name="CISOBOX1" value="Keyword Search Bulletins" onfocus="if (this.value==this.defaultValue) this.value='';" size="25">
                <input type="submit" value="Go" class="button">
                </form> 
            </li>  
            </ul>
        </li>
        <li><a href="../database/index.html">Indiana State Board of Health Monthly Bulletin Vital Statistics (1899-1921)</a></li>
        <li><a href="../unavailable.shtml">Indiana State Board of Health Monthly Bulletin Statistical Tables</a></li>       
        <li><a href="https://idea.iupui.edu/dspace/handle/1805/1641" target="_blank">Medical History Image Collection</a></li> 
        <li><a href="http://library.medicine.iu.edu" target="_blank">Indiana University School of Medicine Library (IUSML)</a></li>
        <li><a href="http://www.in.gov/memories" target="_blank">Indiana State Library - Indiana Memory Digital Collection</a></li>
        <li><a href="../projdoc.shtml">Project Documentation</a></li>
        <li><a href="../sitemap.shtml">Site Map</a></li>
        <li><a href="../contactus.shtml">Contact Us</a></li>
        </ul> 
        </div> 
        </div>
    <!--[if IE]> </div id="IE"> <![endif]-->    
    <!-- END LEFT (TERTIARY) NAVIGATION BAR FOR INDIANA PUBLIC HEALTH DIGITAL LIBRARY -->

            <!-- BEGIN CONTENT AREA -->
            <div id="content">

        <!-- ============================================================= -->

    END_HTML

}


# Display the INPUB footer (for branding).

sub display_inpub_footer() {

    print <<"    END_HTML";
        <!-- ============================================================= -->

            </div>
            <!--END CONTENT AREA -->

        <!-- BEGIN INDIANA UNIVERSITY FOOTER -->
        <div id="footer">
            <p>This project has been funded by the National Library of
            Medicine under Contract No. NO1-LM-6-3503 with the University of
            Illinois at Chicago, Library of the Health Sciences and by the
            Indiana State Library as part of a Library Services and
            Technology Act (LSTA) Digitization Grant.</p>
            
            <br />
            
                <a href="http://medicine.iu.edu" target="_blank">
                <img src="${WEB_ROOT}/img/IUSM-logo.gif" border="0"
                alt="Indiana University School of Medicine logo" /></a>
                <a href="http://www.in.gov/library/" target="_blank">
                <img src="${WEB_ROOT}/img/ISL-logo.gif" border="0"
                alt="Indiana State Library logo" /></a>

            <hr />
            <div id="copyright">
                <div id="statement">
                    <p>Although these works may be freely accessible on the
                    World Wide Web and may not include any statement about
                    copyright, the U.S.  Copyright Act nevertheless provides
                    that such works are protected by copyright. Users must
                    assume that works are protected by copyright until they
                    learn otherwise.</p>
            </div>
        </div>
        <!-- END INDIANA UNIVERSITY FOOTER -->

    END_HTML
}


# Display the table in a web page.
#
# Parameters:
#   $table_caption: Table caption
#   $table:         Table rows, reference to array of array references

sub display_table($$) {

    # Parameters.
    my $table_caption = shift;
    my $pTable= shift;
    my @table = @{$pTable};

    # Table caption.
    print qq(\n);
    print qq(<table class="query_results">\n);
    print qq(  <caption> ${table_caption} </caption>\n);

    # Table column headings.
    my @column_headings = @{$table[0]};
    print qq(  <tr class="heading">\n);

    foreach my $column (@column_headings) {
        print qq(    <td class="column_heading"> ${column} </td>\n);
    }

    print qq(  </tr>\n);

    # Table data rows.
    for (my $row_number = 1;
         $row_number < scalar(@table);
         $row_number++)
    {
        # Beginning of row.
        # Determine if odd/even row, for display purposes.
        my $tr_class = "even_row";
        if (($row_number % 2) == 1) {
            $tr_class = "odd_row";
        }

        print qq(  <tr class="${tr_class}">\n);

        # Row header.
        my @table_row = @{$table[$row_number]};
        my $row_header = $table_row[0];
        print qq(    <th> ${row_header} </th>\n);

        # Row data fields.
        for (my $field_ix = 1; $field_ix < scalar(@table_row); $field_ix++) {
            my $row_field = $table_row[$field_ix];

            # Check if the field is available in the database.
            # Missing rows in the database (for monthly tables that do not
            # include all regions) will cause database fields to be undefined.
            if (!defined($row_field)) {
                $row_field = $DATA_NOT_AVAILABLE;
            }

            print qq(    <td class="statistic_value"> ${row_field} </td>\n);
        }

        # End of row.
        print "  </tr>\n";
    }

    # End of table.
    print "</table>\n\n";

}


# Display form to continue the query,
# by month, region, or statistic.

sub continue_query_form() {

    if (($output_layout eq "mrs") || ($output_layout eq "msr")) {
        continue_query_by_month();
    }
    elsif (($output_layout eq "rms") || ($output_layout eq "rsm")) {
        continue_query_by_region();
    }
    elsif (($output_layout eq "smr") || ($output_layout eq "srm")) {
        continue_query_by_statistic();
    }
    else {
        # Invalid layout option.
        return 0;
    }

}


# Display the query form to choose a new month.

sub continue_query_by_month() {

    # Check if there is more than one month specified for this query.
    if (scalar(@query_months) <= 1) {
        return 0;
    }

    # Find the $current_month and $current_year in @query_months.
    my $month_ix = 0;
    until (($query_months[$month_ix]->{sql_month} == $current_month) &&
           ($query_months[$month_ix]->{sql_year} == $current_year))
    {
        $month_ix++;

        if ($month_ix >= scalar(@query_months)) {
            # Could not find $current_month and $current_year in
            # @query_months.
            $month_ix = 0;
            last;
        }
    }

    # Menu of month names / labels.
    my @month_names = ();
    my @month_labels = ();
    foreach my $month_year (@query_months) {
        push @month_names,
            $month_year->{sql_month} . ' ' . $month_year->{sql_year};
        push @month_labels,
            $month_as_string[$month_year->{sql_month}] . ' ' .
            $month_year->{sql_year};
    }

    # Display the CGI form.
    continue_query_html(
        dimension               => 'month',
        query_names             => \@month_names,
        query_labels            => \@month_labels,
        selected_ix             => $month_ix,
    );

}

# Display the query form to choose a new region.

sub continue_query_by_region() {

    # Check if there is more than one region specified for this query.
    if (scalar(@query_regions) <= 1) {
        return 0;
    }

    # Find the $current_region in @query_regions.
    my $region_ix = 0;
    until ($query_regions[$region_ix] eq $current_region) {
        $region_ix++;
        if ($region_ix >= scalar(@query_regions)) {
            # Could not find $current_region in @query_regions.
            $region_ix = 0;
            last;
        }
    }

    # Menu of region names / labels.
    my @region_names = ();
    my @region_labels = ();
    foreach my $region (@query_regions) {
        push @region_names, $region;
        push @region_labels, $regionName_to_regionLabel{$region};
    }

    # Display the CGI form.
    continue_query_html(
        dimension               => 'region',
        query_names             => \@region_names,
        query_labels            => \@region_labels,
        selected_ix             => $region_ix,
    );

}


# Display the query form to choose a new statistic.

sub continue_query_by_statistic() {

    # Check if there is more than one statistic specified for this query.
    if (scalar(@query_statistics) <= 1) {
        return 0;
    }

    # Find the $current_statistic in @query_statistics.
    my $statistic_ix = 0;
    until ($query_statistics[$statistic_ix] eq $current_statistic) {
        $statistic_ix++;
        if ($statistic_ix >= scalar(@query_statistics)) {
            # Could not find $current_statistic in @query_statistics.
            $statistic_ix = 0;
            last;
        }
    }

    # Menu of statistic names / labels.
    my @statistic_names = ();
    my @statistic_labels = ();
    foreach my $statistic (@query_statistics) {
        push @statistic_names, $statistic;
        push @statistic_labels, $statisticName_to_statisticLabel{$statistic};
    }

    # Display the CGI form.
    continue_query_html(
        dimension               => 'statistic',
        query_names             => \@statistic_names,
        query_labels            => \@statistic_labels,
        selected_ix             => $statistic_ix,
    );

}


# Display the CGI form to continue the query.
#
# Parameters:
#   $dimension:             Dimension type (month/region/statistic)
#   @query_names:           Names for menu
#   @query_labels:          Labels for menu
#   $selected_ix:           Currently SELECTED index in menu

sub continue_query_html(@) {

    # Parameters.
    my %parameters = @_;

    my $dimension = $parameters{dimension};

    my $pQueryNames = $parameters{query_names};
    my @query_names = @{$pQueryNames};

    my $pQueryLabels = $parameters{query_labels};
    my @query_labels = @{$pQueryLabels};

    my $selected_ix = $parameters{selected_ix};

    # Threshold for using radio buttons vs. menu.
    my $MENU_THRESHOLD = 5;

    if (scalar(@query_names) <= $MENU_THRESHOLD) {
        # Use links to continue query.

        # Instructions, for links.
        print <<"        HTML";
            <p>
            Multiple ${dimension}s selected.
            The tables below show only one ${dimension} at a time.
            To view your additional ${dimension}s,
            click the link for the ${dimension} from the list below.
            </p>

        HTML

        # List of links.
        for (my $i = 0; $i < scalar(@query_names); $i++) {
            my $q_name = $query_names[$i];
            my $q_label = $query_labels[$i];

            if ($dimension eq 'month') {
                # In the month/year, replace space with plus-sign.
                $q_name =~ s/ /+/ ;
            }

            # Compose the URL for the query.
            my $query_url =
                "${CGI_BIN}/inpub.cgi?" .
                'query_new_table=New+table' .
                "&new_${dimension}=${q_name}" .
                query_state_string();

            # Display the link for the query.
            print
                qq(  <a href="${query_url}">\n),
                qq(  ${q_label}</a> <br />\n);
        }

        print qq(  <br /> <br />\n\n);
    }

    else {
        # Use drop-down menu to continue query.

        # Instructions, for drop-down menu.
        print <<"        HTML";
            <p>
            Multiple ${dimension}s selected.
            The tables below show only one ${dimension} at a time.
            To view your additional ${dimension}s,
            make a selection from the drop-down menu
            and click the "View ${dimension}" button.
            </p>

        HTML

        # Begin <form>
        print qq(<form action="${CGI_BIN}/inpub.cgi" method="get">\n);

        # Menu of new months/regions/statistics.
        print qq(  <select name="new_${dimension}">\n);
        for (my $i = 0; $i < scalar(@query_names); $i++) {
            my $q_name = $query_names[$i];
            my $q_label = $query_labels[$i];
            my $selected = "";
            if ($i == $selected_ix) {
                $selected = "SELECTED";
            }
            print
                qq(    <option ${selected} value="${q_name}">${q_label}),
                qq(</option>\n);
        }
        print qq(  </select>\n);

        # 'View table' button.
        print
            qq(  <input type="submit" name="query_new_table" ),
            qq(value="View ${dimension}">\n);

        # Save the query state, using hidden form fields.
        save_query_state();

        # End </form>
        print qq(</form>\n);
        print qq(<br /> <br />\n);
        print qq(\n);

    }
}

# Display additional query options, as links (URLs).

sub display_additional_query_options() {

    # Start of bullet list
    print qq(<ul>\n);

    # New query.
    my $new_query_url = "${WEB_ROOT}/database/index.html";

    print
        qq(  <li>\n),
        qq(    <a href="${new_query_url}">Create a new query.</a> <br />\n),
        qq(  </li>\n);

    # Download query results in spreadsheet format
    my $spreadsheet_url =
        "${CGI_BIN}/inpub_download.cgi?" .
        'query_download=Download+as+spreadsheet' .
        query_state_string();

    print
        qq(  <li>\n),
        qq(    <a href="${spreadsheet_url}">\n),
        qq(    Download query results in spreadsheet format.</a> <br />\n),
        qq(  </li>\n);

    # Download entire Indiana mortality database
    my $database_url = "${WEB_ROOT}/database/inpub_database.csv";

    my $csv_database_size = "???";
    my $csv_database_pathname =
        "${LOCAL_WEB_ROOT}/database/inpub_database.csv";
    if (-e $csv_database_pathname) {
        $csv_database_size =
            sprintf("%.0f", (-s $csv_database_pathname) / 1024);
    }

    print
        qq(  <li>\n),
        qq(    <a href="${database_url}">\n),
        qq(    Download the entire Indiana mortality database\n),
        qq(    in spreadsheet format ($csv_database_size KB).</a> <br />\n),
        qq(  </li>\n);

    # End of bullet list
    print qq(</ul>\n);

}

sub display_additional_query_options_with_buttons() {

    # CGI form for the next query.
    print qq(<table class="form">\n);

    # Heading
    print qq(  <tr class="heading">\n);
    print qq(    <td colspan="2">\n);
    print qq(      <strong>Additional Options</strong>\n);
    print qq(    </td>\n);
    print qq(  </tr>\n);

    # New query.
    print qq(  <tr>\n);
    print qq(    <form action="${WEB_ROOT}/database/index.html">\n);
    print qq(      <td>\n);
    print qq(        <input type="submit" name="new_query" ) .
        qq(value="New query">\n);
    print qq(      </td>\n);

    print qq(      <td>\n);
    print qq(        Create a new query.\n);
    print qq(      </td>\n);
    print qq(    </form>\n);
    print qq(  </tr>\n);

    # Download query results in spreadsheet format
    print qq(  <tr>\n);
    print qq(    <form action="${CGI_BIN}/inpub_download.cgi" method="get">\n);

    # Save the query state, using hidden form fields.
    save_query_state();

    print qq(      <td>\n);
    print
        qq(        <input type="submit" name="query_download" ) .
        qq(value="Download query results">\n);
    print qq(      </td>\n);

    print qq(      <td>\n);
    print qq(        Download the query results in spreadsheet format.\n);
    print qq(      </td>\n);

    print qq(    </form>\n);
    print qq(  </tr>\n);

    # Download entire Indiana mortality database
    print qq(  <tr>\n);
    print qq(    <form action="inpub_database.csv">\n);
    print qq(      <td>\n);
    print qq(        <input type="submit" name="download" ) .
        qq(value="Download entire database">\n);
    print qq(      </td>\n);

    print qq(      <td>\n);
    print qq(        Download the entire Indiana mortality database\n);
    print qq(        in spreadsheet format (35 KB).\n);
    print qq(      </td>\n);
    print qq(    </form>\n);
    print qq(  </tr>\n);

    print qq(</table>\n\n);

}


# Save the query state, using hidden form fields.
# This allows the user to step to the next table.

sub save_query_state() {

    print "\n";

    # Output layout
    print "  ", hidden ('output_layout', $output_layout), "\n";

    # Months (starting and ending month/year)
    print "  ", hidden ('starting_month', $query_months[0]->{sql_month}), "\n";
    print "  ", hidden ('starting_year',  $query_months[0]->{sql_year}), "\n";
    print
        "  ",
        hidden ('ending_month',   $query_months[$#query_months]->{sql_month}),
        "\n";
    print
        "  ",
        hidden ('ending_year',    $query_months[$#query_months]->{sql_year}),
        "\n";

    # Regions
    print
        "  ",
        hidden(
            -name    => 'region',
            -default => \@query_regions
        ),
        "\n";

    # Statistics
    print
        "  ",
        hidden(
            -name    => 'statistic',
            -default => \@query_statistics
        ),
        "\n";

    print "\n";

}

# Save the query state to a single string, delimited by ampersand.

sub query_state_string() {

    my $query_string = "";

    # Output layout
    $query_string .= '&output_layout=' . $output_layout;

    # Months (starting and ending month/year)
    $query_string .= '&starting_month=' .
        $query_months[0]->{sql_month};
    $query_string .= '&starting_year=' .
        $query_months[0]->{sql_year};
    $query_string .= '&ending_month=' .
        $query_months[$#query_months]->{sql_month};
    $query_string .= '&ending_year=' .
        $query_months[$#query_months]->{sql_year};

    # Regions
    foreach my $region (@query_regions) {
        $query_string .= '&region=' . $region;
    }

    # Statistics
    foreach my $statistic (@query_statistics) {
        $query_string .= '&statistic=' . $statistic;
    }

    return $query_string;

}

# =================================================================

# Download the query results in CSV format.

sub download_csv() {

    # HTTP header for CSV file
    print
        qq(Content-Type: text/csv; charset=ISO-8859-1\n),
        qq(Content-Disposition: attachment; filename="query_results.csv"\n),
        qq(\n);

    # Column headers.
    # Always start with (Month, Year, Region).
    my @column_headers = ('Month', 'Year', 'Region');

    # Column header labels for Statistics.
    foreach my $statistic_name (@query_statistics) {
        my $statistic_label = $statisticName_to_statisticLabel{$statistic_name};
        push @column_headers, $statistic_label;
    }

    # Convert the column headers to a CSV string.
    print convert_to_spreadsheet(@column_headers);

    # Database records.

    # Connect to the INPUB database.
    $dbh = inpub_connect('inpub');

    # SQL SELECT statement:
    #   SELECT month, year, region, <statistic_1>, ..., <statistic_n>
    #   FROM mortality
    #   WHERE month = ? AND year = ? AND region = ?

    my $sth = $dbh->prepare(
        "SELECT month, year, region, " .
        join(', ', @query_statistics) . ' ' .
        "FROM mortality " .
        "WHERE month = ? AND year = ? AND region = ?"
    );

    foreach my $month (@query_months) {

        foreach my $region (@query_regions) {

            # Execute the query.
            $sth->bind_param(1, $month->{sql_month});
            $sth->bind_param(2, $month->{sql_year});
            $sth->bind_param(3, $region);
            $sth->execute();

            # Fetch record, and build the CSV record.
            my @csv_record = ();
            push @csv_record, $month_as_string[$month->{sql_month}];
            push @csv_record, $month->{sql_year};
            push @csv_record, $regionName_to_regionLabel{$region};

            my $pRecord = $sth->fetchrow_hashref();
            foreach my $statistic_name (@query_statistics) {
                my $statistic_value = $pRecord->{$statistic_name};

                # Check if the field is available in the database.
                # Missing rows in the database (for monthly tables that do not
                # include all regions) will cause database fields to be
                # undefined.
                if (!defined($statistic_value)) {
                    $statistic_value = $DATA_NOT_AVAILABLE;
                }

                push @csv_record, $statistic_value;
            }

            # Convert the record to a CSV string.
            print convert_to_spreadsheet(@csv_record);
        }
    }

    # Disconnect from the database.
    $sth->finish();
    $dbh->disconnect()
        or warn "Disconnection failed: $DBI::errstr\n";

    return 1;
}

# =================================================================

    sub inpub_connect($) {

        my $database = shift;

        # Connect to the SQLite database.
        return DBI->connect(
            "dbi:SQLite:dbname=inpub.db", "", "");

        # Connect to the MySql database.
        # my $db_username = 'root';
        # my $db_password = '***';
        # return DBI->connect(
        #   "DBI:mysql:${database}", $db_username, $db_password);

        # Connect to the MS Access database.
        # return DBI->connect(
        #   "dbi:ODBC:driver=Microsoft Access Driver (*.mdb);dbq=${database}.mdb",
        #   '', '');

    }

# =================================================================

# Compare months for equality.
#
# Parameters;
#   $lMonth: month to be compared
#   $rMonth: month to be compared
#
# Return value:
#   Returns true, if the two months are equal.

sub months_equal($$) {
    my $lMonth = shift;
    my $rMonth = shift;
    my $result = 0;

    if (($lMonth->{sql_month} == $rMonth->{sql_month}) &&
        ($lMonth->{sql_year}  == $rMonth->{sql_year}))
    {
        $result = 1;
    }

    return $result;
}

# Calculate the value of the next month.
#
# Parameters:
#   $time_direction: Time direction -- "forward" or "reverse"
#   $month_year:     Current month and year
#
# Return value:
#   Returns the next month.

sub next_month($$) {
    my $time_direction = shift;
    my $month_year = shift;
    my $month = $month_year->{sql_month};
    my $year = $month_year->{sql_year};

    if ($time_direction eq "forward") {
        $month++;
        if ($month > 12) {
            # Wrap to the next year.
            $month = 1;
            $year++;
        }
    }
    else {
        $month--;
        if ($month < 1) {
            # Wrap to previous year.
            $month = 12;
            $year--;
        }
    }

    my $result = {};
    $result->{sql_month} = $month;
    $result->{sql_year} = $year;
    return $result;
}


# Calculate the death rate (per 100,000).
#
# Parameters:
#   $population:        Population
#   $statistic_value:   Statistic value (number of deaths)

sub death_rate($$) {

    # Parameters
    my $population = shift;
    my $statistic_value = shift;

    # Check if the field is available in the database.
    # Missing rows in the database (for monthly tables that do not include
    # all regions) will cause database fields to be undefined.
    if (!defined($population)) {
        $population = $DATA_NOT_AVAILABLE;
    }
    if (!defined($statistic_value)) {
        $statistic_value = $DATA_NOT_AVAILABLE;
    }

    # Check if the statistic is the Population
    if ($population eq $statistic_value) {
        return $DATA_NOT_AVAILABLE;
    }

    # Check if the statistic is not available
    elsif ($statistic_value eq $DATA_NOT_AVAILABLE) {
        return $DATA_NOT_AVAILABLE;
    }

    # Calculate the death rate.
    else {
        my $death_rate_value = $statistic_value / ($population / 100000);
        return sprintf("%.2f", $death_rate_value);
    }
}

# Convert the fields to spreadsheet format (CSV).
#
# This is a hand-coded replacement for the function in Text:CSV_XS.
# The formatting rules for CSV are the following:
#   (1) Delimit fields with comma.
#   (2) Terminate row with newline.
#   (3) If field contains one of the following characters,
#   then wrap it in double-quotes: comma, newline, double quote, white space
#   (4) If field contains a double-quote,
#   then escape each double-quote with a second double-quote.
#
# Parameters:
#   @spreadsheet_fields:    Spreadsheet fields

sub convert_to_spreadsheet(@) {

    # Parameters
    my @spreadsheet_fields = @_;

    my $csv_string = "";    # return value

    # Process each field.
    foreach my $field (@spreadsheet_fields) {
        # Escape each double-quote in the field with a second double-quote.
        $field =~ s/"/""/ ;

        # If the field contains any of the following characters,
        # then wrap the field in double-quotes:
        #    comma, double-quote, newline, white space
        if ($field =~ m/[,"\n\s]/ ) {
            $field = '"' . $field . '"';
        }

        # Delimit the field with a comma.
        $csv_string .= $field . ',';
    }

    # Replace the trailing comma with a newline.
    $csv_string =~ s/,$/\n/ ;

    # Return the CSV string.
    return $csv_string;
}


1;

