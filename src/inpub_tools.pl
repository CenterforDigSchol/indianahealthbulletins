#! /usr/bin/perl
#
# INPUB tools
#
#   Database:
#   * csv:              Database as a CSV spreadsheet
#   * formatted_csv:    Database as a CSV spreadsheet, formatted
#   * html:             Database as an HTML table
#
#   CSV spreadsheet:
#   * csv_to_html:      Convert CSV spreadsheet to HTML table
#   * remove_id:        Remove ID column from CSV spreadsheet

    use strict;
    use warnings;
    use DBI;
    use Text::CSV_XS;

    # Subroutine prototypes
    sub database_to_csv();
    sub database_to_formatted_csv();
    sub database_to_html();
    sub inpub_connect($);

    sub spreadsheet_to_html($);
    sub remove_id_column($);

    # Data not available
    my $DATA_NOT_AVAILABLE = '...';

# =================================================================

    # Usage string
    my $usage_string = qq(Usage:
        csv                         -- Database as a CSV spreadsheet
        formatted_csv               -- Database as a formatted CSV spreadsheet
        html                        -- Database as an HTML table
        csv_to_html csv_file        -- CSV spreadsheet as an HTML table
        remove_id_column csv_file   -- Remove ID column from spreadsheet
        help                        -- Display usage string
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
        "urban"             =>  "Urban, population over 5,000",
        "rural"             =>  "Rural, population under 5,000",
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
        "cerebro_spinal_fever"   => "Cerebro-Spinal Fever",
        "polio"                  => "Poliomyelitis",
        "influenza"              => "Influenza",
        "septicemia"             => "Puerperal Septicemia",
        "cancer"                 => "Cancer",
        "external_causes"        => "External Causes",
        "violence"               => "Violence",
        "smallpox"               => "Smallpox",
        "syphilis"               => "Syphilis",
    );

# =================================================================

    # Mainline --------------------------------------------

    if (@ARGV < 1) {
        print "${usage_string}\n";
        exit;
    }

    my $command = $ARGV[0];

    if ($command eq 'csv') {
        database_to_csv();
    }
    elsif ($command eq 'formatted_csv') {
        database_to_formatted_csv();
    }
    elsif ($command eq 'html') {
        database_to_html();
    }
    elsif ($command eq 'csv_to_html') {
        if (@ARGV != 2) {
            print "${usage_string}\n";
            exit;
        }
        spreadsheet_to_html($ARGV[1]);
    }
    elsif ($command eq 'remove_id_column') {
        if (@ARGV != 2) {
            print "${usage_string}\n";
            exit;
        }
        remove_id_column($ARGV[1]);
    }
    elsif ($command eq 'help') {
        print "${usage_string}\n";
        exit;
    }

    else {
        # Invalid command.
        print "${usage_string}\n";
        exit;
    }

# =================================================================

    # Convert the INPUB database to CSV format.
    # Results are printed to standard output.

    sub database_to_csv() {

        # Text::CSV_XS object.
        my $csv = Text::CSV_XS->new;

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # SELECT the entire table.
        my $sth = $dbh->prepare("SELECT * FROM mortality");
        $sth->execute();

        # Extract the database column names.
        my $pDbNames = $sth->{NAME};
        my @column_headers = @$pDbNames;

        if ($csv->combine(@column_headers)) {
            print $csv->string, "\n";
        }

        # Database records.
        while (my @record = $sth->fetchrow_array) {

            # Convert the list of cell values to a CSV string.
            if ($csv->combine(@record)) {
                print $csv->string, "\n";
            }

        }

        # Disconnect from the database.
        $dbh->disconnect
            or warn "Disconnection failed: $DBI::errstr\n";

    }

# =================================================================

    # Convert the INPUB database to CSV format.
    # Database column names are converted to column labels,
    # months and regions are converted to labels.
    # Results are printed to standard output.

    sub database_to_formatted_csv() {

        # Text::CSV_XS object.
        my $csv = Text::CSV_XS->new;

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # SELECT the entire table.
        my $sth = $dbh->prepare("SELECT * FROM mortality");
        $sth->execute();

        # Extract the database field names.
        my $pDbNames = $sth->{NAME};
        my @column_names = @$pDbNames;

        # Column headers.
        my @column_headers = ();

        foreach my $column_name (@column_names) {
            if  ($column_name eq 'id') {
                push @column_headers, 'id';
            }
            elsif ($column_name eq 'month') {
                push @column_headers, 'Month';
            }
            elsif ($column_name eq 'year') {
                push @column_headers, 'Year';
            }
            elsif ($column_name eq 'region') {
                push @column_headers, 'Region';
            }
            else {
                # Statistic
                my $statistic_label =
                    $statisticName_to_statisticLabel{$column_name};
                push @column_headers, $statistic_label;
            }
        }

        if ($csv->combine(@column_headers)) {
            print $csv->string, "\n";
        }

        # Database records.
        while (my $pRecord = $sth->fetchrow_hashref()) {

            # Database record, to be written to the CSV file.
            my @db_record = ();

            foreach my $column_name (@column_names) {
                if  ($column_name eq 'id') {
                    # ID
                    push @db_record, $pRecord->{'id'};
                }
                elsif ($column_name eq 'month') {
                    # Month
                    my $month_value = $pRecord->{'month'};
                    my $month_label = $month_as_string[$month_value];
                    push @db_record, $month_label;
                }
                elsif ($column_name eq 'year') {
                    # Year
                    my $year_value = $pRecord->{'year'};
                    push @db_record, $year_value;
                }
                elsif ($column_name eq 'region') {
                    # Region
                    my $region_name = $pRecord->{'region'};
                    my $region_label = $regionName_to_regionLabel{$region_name};
                    push @db_record, $region_label;
                }
                else {
                    # Statistic
                    my $statistic_value = $pRecord->{$column_name};
                    push @db_record, $statistic_value;
                }
            }

            # Convert the list of field values to a CSV string.
            if ($csv->combine(@db_record)) {
                print $csv->string, "\n";
            }
        }

        # Disconnect from the database.
        $dbh->disconnect
            or warn "Disconnection failed: $DBI::errstr\n";

    }

# =================================================================

    # Display the INPUB database in HTML format.
    # Results are printed to standard output.

    sub database_to_html() {

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # SELECT the entire table.
        my $sth = $dbh->prepare("SELECT * FROM mortality ORDER BY year");
        $sth->execute();

        # Extract the field names.
        my $pDbNames = $sth->{NAME};
        my @column_names = @$pDbNames;

        # Start the HTML table.
        print "<table border=5 cellpadding=10 width=80%>\n";

        # Start the column header row for the HTML table.
        print "<tr>\n";

        # Column headers.
        foreach my $column_name (@column_names) {
            print "    <td>" . "${column_name}" . "</td>\n";
        }

        # End the column header row for the HTML table.
        print "</tr>\n";

        # Generate an HTML table row for each record in the database.
        while (my @record = $sth->fetchrow_array) {
            # Start table row.
            print "<tr>\n";

            # Create HTML table entry for each data field.
            foreach my $dbField (@record) {
                print "    <td>" . "$dbField" . "</td>\n";
            }

            # End table row.
            print "</tr>\n";
        }

        # End the HTML table.
        print "</table>\n";

        # Disconnect from the database.
        $dbh->disconnect
            or warn "Disconnection failed: $DBI::errstr\n";

    }

# =================================================================

    sub inpub_connect($) {

        my $database = shift;

        # Connect to the SQLite database.
        my $dbh = DBI->connect(
            "dbi:SQLite:dbname=inpub.db", "", "");

        # Connect to the MySql database.
        # my $db_username = 'root';
        # my $db_password = '***';
        # my $dbh = DBI->connect(
        #   "DBI:mysql:${database}", $db_username, $db_password);

        # Connect to the MS Access database.
        # my $dbh = DBI->connect(
        #   "dbi:ODBC:driver=Microsoft Access Driver (*.mdb);dbq=${database}.mdb",
        #   '', '');

        # Return the database handle.
        return $dbh;
    }

# =================================================================

    # Convert CSV spreadsheet into an HTML table.
    # Results are printed to standard output.

    sub spreadsheet_to_html($) {

        # Parameters
        my $csv_filename = shift;

        # Text::CSV_XS object.
        my $csv = Text::CSV_XS->new();

        # Open the CSV spreadsheet file.
        open SPREADSHEET, "<$csv_filename"
            or die "Cannot open CSV spreadsheet file: $!\n";

        # Get the column headers.
        my $columnHeaderRow = <SPREADSHEET>;
        my $status = $csv->parse($columnHeaderRow);
        my @columnHeaders = $csv->fields();

        # Start the HTML table.
        print "<table border=5 cellpadding=10 width=80%>\n";

        # Start the column header row for the HTML table.
        print "<tr>\n";

        # Column headers.
        foreach my $column_label (@columnHeaders) {
            print "    <td>" . $column_label . "</td>\n";
        }

        # End the column header row for the HTML table.
        print "</tr>\n";

        # Subsequent rows of the CSV file are the data records.
        while (<SPREADSHEET>) {

            # Extract the fields from this record.
            chomp $_;
            my $status = $csv->parse($_);
            my @columns = $csv->fields();

            # Skip empty rows in the spreadsheet.
            next if (scalar(@columns) == 0);

            # Generate an HTML table for this row in the spreadsheet.

            # Start table row.
            print "<tr>\n";

            # Process each data cell in the spreadsheet row.
            foreach my $dbField (@columns) {

                # Set empty fields to zero.
                if (length($dbField) == 0) {
                    $dbField = 0;
                }

                # Create HTML table data cell for this data field.
                print "    <td>" . "$dbField" . "</td>\n";
            }

            # End table row.
            print "</tr>\n";

        }

        # End the HTML table.
        print "</table>\n";

    }

# =================================================================

    # Remove the ID column from CSV spreadsheet.
    # Note: Doing this manually via MS Excel changes the quoting.
    # Results are printed to standard output.

    sub remove_id_column($) {

        # Parameters
        my $csv_filename = shift;

        # Text::CSV_XS object.
        my $csv = Text::CSV_XS->new();

        # Open the CSV spreadsheet file.
        open SPREADSHEET, "<$csv_filename"
            or die "Cannot open CSV spreadsheet file: $!\n";

        # Process each row of the spreadsheet,
        # removing the first column.
        while (<SPREADSHEET>) {

            # Extract the columns from this record.
            chomp $_;
            my $status = $csv->parse($_);
            my @columns = $csv->fields();

            # Skip empty rows in the spreadsheet.
            next if (scalar(@columns) == 0);

            # Remove the first column of the spreadsheet row.
            shift @columns;

            # Convert the list of column values to a CSV string.
            if ($csv->combine(@columns)) {
                print $csv->string, "\n";
            }

        }

    }

# =================================================================
