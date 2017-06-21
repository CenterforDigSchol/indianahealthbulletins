#! /usr/bin/perl

# Usage:
#   * validate:         Run validation suite
#   * spreadsheet:      Run spreadsheet query
#   * spreadsheet_db:   Download spreadsheet for entire database
#   * (no arguments):   Run custom query

# Custom query results are in file custom_query.htm

    use strict;
    use warnings;
    use CGI qw(:standard);
    use Tie::File;

# =================================================================

    # Subroutine prototypes
    sub run_validation_suite();
    sub run_custom_query($);
    sub run_spreadsheet_query($);
    sub generate_database_spreadsheet();
    sub remove_http_header($);
    sub validate_query_results($);
    sub debug_cgi_input();

# =================================================================

    # Usage string
    my $usage_string = qq(
        validate        -- Run validation suite.
        spreadsheet     -- Download spreadsheet for query.
        spreadsheet_db  -- Download spreadsheet for entire database.
        help            -- Display usage string
        (no arguments)  -- Run custom query.
    );
# =================================================================

    # Mainline  -------------------------------------------

    if (@ARGV == 1) {
        # Validation suite
        if ($ARGV[0] eq 'validate') {
            run_validation_suite();
        }

        elsif ($ARGV[0] eq 'spreadsheet') {
            run_spreadsheet_query(
                "output_layout=mrs&starting_month=1&starting_year=1899&ending_month=12&ending_year=1900&region=indiana&region=northern_counties&region=central_counties&region=southern_counties&region=urban&region=rural&region=class_1_cities&region=class_2_cities&region=class_3_cities&region=class_4_cities&region=class_5_cities&statistic=population&statistic=pulmonary_tuberculosis&statistic=other_tuberculosis&statistic=typhoid&statistic=diptheria_and_croup&statistic=scarlet_fever&statistic=measles&statistic=whooping_cough&statistic=pneumonia&statistic=diarrhea_and_enteritis&statistic=cerebro_spinal_fever&statistic=polio&statistic=influenza&statistic=septicemia&statistic=cancer&statistic=external_causes&statistic=smallpox&statistic=syphilis&query_download=Download+query+results"
            );
        }

        elsif ($ARGV[0] eq 'spreadsheet_db') {
            generate_database_spreadsheet();
        }

        elsif ($ARGV[0] eq 'help') {
            print $usage_string;
            exit;
        }
    }

    else {

        run_custom_query(
            "new_statistic=pneumonia&query_new_table=New+table&output_layout=smr&starting_month=10&starting_year=1899&ending_month=12&ending_year=1899&region=indiana&region=northern_counties&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox"
        );
    }

# =================================================================

    # Run validation suite for the six output layouts.

    sub run_validation_suite() {

        # MRS layout  -------------------------------------
        run_custom_query(
            "new_month=8+1918&query_new_table=New+table&output_layout=mrs&starting_month=6&starting_year=1918&ending_month=10&ending_year=1918&region=indiana&region=urban&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox"
        );

        rename 'custom_query.htm', 'mrs.htm';
        validate_query_results('mrs.htm');

        # MSR layout  -------------------------------------
        run_custom_query(
            "new_month=8+1918&query_new_table=New+table&output_layout=msr&starting_month=6&starting_year=1918&ending_month=10&ending_year=1918&region=indiana&region=urban&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox"
        );

        rename 'custom_query.htm', 'msr.htm';
        validate_query_results('msr.htm');

        # RMS layout  -------------------------------------
        run_custom_query(
            "output_layout=rms&starting_month=6&starting_year=1918&ending_month=10&ending_year=1918&region=indiana&region=urban&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox&new_query=Submit+Query"
        );

        rename 'custom_query.htm', 'rms.htm';
        validate_query_results('rms.htm');

        # RSM layout  -------------------------------------
        run_custom_query(
            "output_layout=rsm&starting_month=6&starting_year=1918&ending_month=10&ending_year=1918&region=indiana&region=urban&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox&new_query=Submit+Query"
        );

        rename 'custom_query.htm', 'rsm.htm';
        validate_query_results('rsm.htm');

        # SMR layout  -------------------------------------
        run_custom_query(
            "new_statistic=pneumonia&query_new_table=New+table&output_layout=smr&starting_month=6&starting_year=1918&ending_month=10&ending_year=1918&region=indiana&region=urban&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox"
        );

        rename 'custom_query.htm', 'smr.htm';
        validate_query_results('smr.htm');

        # SRM layout  -------------------------------------
        run_custom_query(
            "new_statistic=pneumonia&query_new_table=New+table&output_layout=srm&starting_month=6&starting_year=1918&ending_month=10&ending_year=1918&region=indiana&region=urban&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox"
        );

        rename 'custom_query.htm', 'srm.htm';
        validate_query_results('srm.htm');

        # Spreadsheet query  ------------------------------
        run_spreadsheet_query(
            "output_layout=smr&starting_month=6&starting_year=1918&ending_month=10&ending_year=1918&region=indiana&region=urban&region=rural&statistic=population&statistic=pneumonia&statistic=influenza&statistic=smallpox&query_download=Download+query+results"
        );

        rename 'custom_query.csv', 'query_spreadsheet.csv';
        validate_query_results('query_spreadsheet.csv');

    }

# =================================================================

    # Runs the specified query.
    # Query results file is custom_query.htm.

    sub run_custom_query($) {

        # Parameters.
        my $query_string = shift;

        # Setup environment.
        $ENV{'REQUEST_METHOD'} = 'GET';
        $ENV{'QUERY_STRING'} = $query_string;

        # Run the query.
        system('perl inpub.cgi > custom_query.htm');

        # Remove the HTTP header from the query results file.
        remove_http_header('custom_query.htm');
    }

# =================================================================

    # Downloads CSV spreadsheet for the specified query.
    # Query results file is custom_query.csv

    sub run_spreadsheet_query($) {

        # Parameters.
        my $query_string = shift;

        # Setup environment.
        $ENV{'REQUEST_METHOD'} = 'GET';
        $ENV{'QUERY_STRING'} = $query_string;

        # Run the query.
        system('perl inpub_download.cgi > custom_query.csv');
    }

# =================================================================

    # Generate a CSV spreadsheet for the entire database.

    sub generate_database_spreadsheet() {

        run_spreadsheet_query(
            "http://inpub.medicine.iu.edu/cgi-bin/inpub.cgi?output_layout=mrs&starting_month=10&starting_year=1899&ending_month=12&ending_year=1927&region=indiana&region=northern_counties&region=central_counties&region=southern_counties&region=urban&region=rural&region=class_1_cities&region=class_2_cities&region=class_3_cities&region=class_4_cities&region=class_5_cities&statistic=population&statistic=births&statistic=total_deaths&statistic=pulmonary_tuberculosis&statistic=other_tuberculosis&statistic=typhoid&statistic=diptheria_and_croup&statistic=diptheria&statistic=croup&statistic=scarlet_fever&statistic=measles&statistic=whooping_cough&statistic=pneumonia&statistic=diarrhea_and_enteritis&statistic=diarrhea_under_five&statistic=cerebro_spinal_fever&statistic=polio&statistic=influenza&statistic=septicemia&statistic=cancer&statistic=external_causes&statistic=violence&statistic=smallpox&statistic=syphilis&query_download=Download+query+results"
        );

    }

# =================================================================

    # Remove the HTTP header from the query results file.
    sub remove_http_header($) {

        # Parameters.
        my $query_results_filename = shift;

        tie my @query_results, 'Tie::File', "${query_results_filename}"
            or die "Cannot tie query results file: $!\n";

        # Remove the first two lines, which are the HTTP header.
        shift @query_results;
        shift @query_results;

        untie @query_results;
    }

# =================================================================

    sub validate_query_results($) {

        # Parameters.
        my $query_results_filename = shift;

        print "Validating ${query_results_filename} ...\n";

        # Compare the new file against the master file in the query_results
        # directory, using the diff utility.
        system(
            'C:/Program Files/GnuWin32/bin/diff.exe',
            $query_results_filename,
            "query_results/${query_results_filename}"
        );
    }

# =================================================================

    # Debug CGI input
    sub debug_cgi_input() {
        my $pCGI = new CGI;

        print "REQUEST_METHOD: " . $ENV{'REQUEST_METHOD'} . "\n";
        print "QUERY_STRING: " . $ENV{'QUERY_STRING'} . "\n";
        print "Number of CGI parameters: " . $pCGI->param() . "\n";
        foreach my $param_name ($pCGI->param()) {
            print "${param_name}: " . $pCGI->param($param_name) . "\n";
        }
    }

# =================================================================
