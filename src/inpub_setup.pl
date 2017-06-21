#
# INPUB maintenance utilities:
#
#   * create:   Create database table.
#   * copy:     Copy data from old database table to new database table.
#   * load:     Load data from spreadsheet (.csv file).
#   * update:   Update selected fields from spreadsheet.
#   * add:      Add a new column to the INPUB database.
#   * default:  MS Access: Set undefined (NULL) fields to default value.
#

    use strict;
    use warnings;
    use Text::CSV_XS;
    use DBI;

# Subroutine prototypes -------------------------------------

    sub create_mysql_table();
    sub create_msaccess_table();
    sub copy_database();
    sub load_spreadsheet($);
    sub update_selected_fields($);
    sub default_data();
    sub add_column($);

    sub delete_table();
    sub inpub_connect($);

# Global variables ------------------------------------------

    my $usage_string = qq(Usage:
        create mysql    -- Create MySQL database table
        create access   -- Create MS Access database table
        copy            -- Copy from old database to new database
        load file.csv   -- Load spreadsheet from .csv file
        update file.csv -- Update selected fields from spreadsheet
        add newColumn   -- Add new column to table
        default         -- Set undefined fields to default value
        help            -- Display usage string.
    );

    # Map month from string value to numeric value.
    my %month_as_number = (
        "january"   => 1,
        "february"  => 2,
        "march"     => 3,
        "april"     => 4,
        "may"       => 5,
        "june"      => 6,
        "july"      => 7,
        "august"    => 8,
        "september" => 9,
        "october"   => 10,
        "november"  => 11,
        "december"  => 12
    );

    # Map Region label to Region Name
    my %regionLabel_to_regionName = (
        "Indiana (statewide)"                   => "indiana",
        "Northern counties"                     => "northern_counties",
        "Central counties"                      => "central_counties",
        "Southern counties"                     => "southern_counties",
        "Urban"                                 => "urban",
        "Rural"                                 => "rural",
        "Cities, class 1"                       => "class_1_cities",
        "Cities, class 2"                       => "class_2_cities",
        "Cities, class 3"                       => "class_3_cities",
        "Cities, class 4"                       => "class_4_cities",
        "Cities, class 5"                       => "class_5_cities",

        # for backward compatibility
        "Urban, population over 5,000"          => "urban",
        "Rural, population under 5,000"         => "rural",
        "Cities, population over 100,000"       => "class_1_cities",
        "Cities, population 45,000 to 100,000"  => "class_2_cities",
        "Cities, population 20,000 to 45,000"   => "class_3_cities",
        "Cities, population 10,000 to 20,000"   => "class_4_cities",
        "Cities, population 5,000 to 10,000"    => "class_5_cities",
    );

    # Map Column label to Database name
    my %columnLabel_to_dbName = (
        "Month"                                 => "month",
        "Year"                                  => "year",
        "Region"                                => "region",
        "Population"                            => "population",
        "Births"                                => "births",
        "Total Deaths"                          => "total_deaths",
        "Tuberculosis"                          => "tuberculosis",
        "Pulmonary Tuberculosis"                => "pulmonary_tuberculosis",
        "Other Forms, Tuberculosis"             => "other_tuberculosis",
        "Typhoid Fever"                         => "typhoid",
        "Diptheria and Croup"                   => "diptheria_and_croup",
        "Diptheria"                             => "diptheria",
        "Croup"                                 => "croup",
        "Scarlet Fever"                         => "scarlet_fever",
        "Measles"                               => "measles",
        "Whooping Cough"                        => "whooping_cough",
        "Pneumonia"                             => "pneumonia",
        "Diarrhea and Enteritis, Under 2 Years" => "diarrhea_and_enteritis",
        "Diarrheal Diseases, Under 5 Years"     => "diarrhea_under_five",
        "Meningitis"                            => "cerebro_spinal_fever",
        "Poliomyelitis"                         => "polio",
        "Influenza"                             => "influenza",
        "Puerperal"                             => "septicemia",
        "Cancer"                                => "cancer",
        "External Causes"                       => "external_causes",
        "Violence"                              => "violence",
        "Accidental"                            => "accidental",
        "Suicide"                               => "suicide",
        "Homicidal"                             => "homicidal",
        "Smallpox"                              => "smallpox",
        "Syphilis"                              => "syphilis",
        "Heart Disease"                         => "heart_disease",
        "Apoplexy"                              => "apoplexy",
        "Bright's Disease"                      => "brights_disease",
        "Diabetes"                              => "diabetes",
        "Goiter"                                => "goiter",

        # for backward compatibility
        "Lobar and Broncho Pneumonia"           => "pneumonia",
        "Cerebro-Spinal Fever"                  => "cerebro_spinal_fever",
        "Acute Anterior Poliomyelitis"          => "polio",
        "Puerperal Septicemia"                  => "septicemia",
    );

# =================================================================

    # Mainline --------------------------------------------

    if (@ARGV < 1) {
        print "${usage_string}\n";
        exit;
    }

    my $command = $ARGV[0];

    if ($command eq 'create') {
        if (@ARGV != 2) {
            print "${usage_string}\n";
            exit;
        }
        my $db_vendor = $ARGV[1];
        if ($db_vendor eq "mysql") {
            create_mysql_table()
        }
        elsif ($db_vendor eq "access") {
            create_msaccess_table()
        }
        else {
            print "${usage_string}\n";
            exit;
        }
    }

    elsif ($command eq 'copy') {
        copy_database();
    }

    elsif ($command eq 'load') {
        if (@ARGV != 2) {
            print "${usage_string}\n";
            exit;
        }
        my $csv_filename = $ARGV[1];
        load_spreadsheet($csv_filename);
    }

    elsif ($command eq 'update') {
        if (@ARGV != 2) {
            print "${usage_string}\n";
            exit;
        }
        my $csv_filename = $ARGV[1];
        update_selected_fields($csv_filename);
    }

    elsif ($command eq 'default') {
        default_data();
    }

    elsif ($command eq 'add') {
        if (@ARGV != 2) {
            print "${usage_string}\n";
            exit;
        }
        my $column_name = $ARGV[1];
        add_column($column_name);
    }

    elsif ($command eq 'help') {
        print "${usage_string}\n";
        exit;
    }

    else {
        # Invalid command
        print "${usage_string}\n";
        exit;
    }

    exit;

# =================================================================

    # Create MySQL database table.

    sub create_mysql_table() {

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # Set default statistic value to '...'
        my $NA = $dbh->quote('...');

        # Create the "mortality" table.
        my $sql = qq/ CREATE TABLE mortality (
            id                      INT NOT NULL AUTO_INCREMENT,
            month                   INT NOT NULL,
            year                    INT NOT NULL,
            region                  VARCHAR(255) NOT NULL,
            population              VARCHAR(255) DEFAULT ${NA},
            births                  VARCHAR(255) DEFAULT ${NA},
            total_deaths            VARCHAR(255) DEFAULT ${NA},
            pulmonary_tuberculosis  VARCHAR(255) DEFAULT ${NA},
            other_tuberculosis      VARCHAR(255) DEFAULT ${NA},
            typhoid                 VARCHAR(255) DEFAULT ${NA},
            diptheria_and_croup     VARCHAR(255) DEFAULT ${NA},
            scarlet_fever           VARCHAR(255) DEFAULT ${NA},
            measles                 VARCHAR(255) DEFAULT ${NA},
            whooping_cough          VARCHAR(255) DEFAULT ${NA},
            pneumonia               VARCHAR(255) DEFAULT ${NA},
            diarrhea_and_enteritis  VARCHAR(255) DEFAULT ${NA},
            cerebro_spinal_fever    VARCHAR(255) DEFAULT ${NA},
            polio                   VARCHAR(255) DEFAULT ${NA},
            influenza               VARCHAR(255) DEFAULT ${NA},
            septicemia              VARCHAR(255) DEFAULT ${NA},
            cancer                  VARCHAR(255) DEFAULT ${NA},
            external_causes         VARCHAR(255) DEFAULT ${NA},
            smallpox                VARCHAR(255) DEFAULT ${NA},
            syphilis                VARCHAR(255) DEFAULT ${NA},
            PRIMARY KEY (id)
            )
        /;

        my $status = $dbh->do($sql);

        if ($status) {
            print "mortality table created successfully.\n";
        }
        else {
            print "\n\nERROR:  $DBI::errstr\n";
        }

        # Disconnect from the database.
        $dbh->disconnect;

    }

# =================================================================

    # Create the MS Access database table.

    sub create_msaccess_table() {

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # Create the "mortality" table.
        my $sql = qq{ CREATE TABLE mortality (
            id                      INT NOT NULL PRIMARY KEY,
            month                   INT NOT NULL,
            year                    INT NOT NULL,
            region                  VARCHAR(255) NOT NULL,
            population              VARCHAR(255),
            births                  VARCHAR(255),
            total_deaths            VARCHAR(255),
            pulmonary_tuberculosis  VARCHAR(255),
            other_tuberculosis      VARCHAR(255),
            typhoid                 VARCHAR(255),
            diptheria_and_croup     VARCHAR(255),
            scarlet_fever           VARCHAR(255),
            measles                 VARCHAR(255),
            whooping_cough          VARCHAR(255),
            pneumonia               VARCHAR(255),
            diarrhea_and_enteritis  VARCHAR(255),
            cerebro_spinal_fever    VARCHAR(255),
            polio                   VARCHAR(255),
            influenza               VARCHAR(255),
            septicemia              VARCHAR(255),
            cancer                  VARCHAR(255),
            external_causes         VARCHAR(255),
            smallpox                VARCHAR(255),
            syphilis                VARCHAR(255)
            )
        };

        my $status = $dbh->do($sql);

        if ($status) {
            print "Set the id Data Type to AutoNumber.\n";
        }
        else {
            print "\n\nERROR:  $DBI::errstr\n";
        }

        # Disconnect from the database.
        $dbh->disconnect;

    }

# =================================================================

    sub copy_database() {

        # Connect to the INPUB database.
        my $dbh_old = inpub_connect('inpub_master');
        my $dbh_new = inpub_connect('inpub');

        # Do a SELECT to get all of the data from the old database table.
        my $sql_select = "SELECT * FROM mortality";
        my $sth_old = $dbh_old->prepare($sql_select);
        $sth_old->execute();

        # Get the column names from the old database.
        # Note: Do not include the 'id' column.
        my $pdb_column_names = $sth_old->{NAME};
        my @db_column_names = ();
        foreach my $db_name (@{$pdb_column_names}) {
            if ($db_name ne 'id') {
                push @db_column_names, $db_name;
            }
        }

        # Process each record from the old database table.
        while (my $pRecord = $sth_old->fetchrow_hashref()) {

            # Extract the data from the old record.
            my @db_record = ();
            foreach my $db_name (@db_column_names) {
                my $db_value = $pRecord->{$db_name};
                push @db_record, $db_value;
            }

            # INSERT record into the new database table.
            @db_record = map{$dbh_new->quote($_)} @db_record;

            my $sql_insert = "INSERT into mortality ("
                . join(", ", @db_column_names)
                . ") VALUES ("
                . join(", ", @db_record)
                . ")";

            $dbh_new->do($sql_insert);
        }

        # Disconnect from the database.
        $dbh_old->disconnect();
        $dbh_new->disconnect();

    }

# =================================================================

    # Load the spreadsheet data into the database table.

    sub load_spreadsheet($) {

        # Parameter: Spreadsheet filename (.csv file)
        my $spreadsheet_filename = shift;

        open SPREADSHEET, "<$spreadsheet_filename"
            or die "Cannot open CSV spreadsheet file: $!\n";

        my $csv = Text::CSV_XS->new();

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # Process the column headers for the spreadsheet,
        # which are in the first row of the spreadsheet.
        my $columnHeaderRow = <SPREADSHEET>;
        my $status = $csv->parse($columnHeaderRow);
        my @columnLabels = $csv->fields();

        # Process the records,
        # which are in the subsequent rows of the spreadsheet.
        while (<SPREADSHEET>) {

            # Extract the fields from this record.
            chomp $_;
            my $status = $csv->parse($_);
            my @columns = $csv->fields();

            # Skip empty rows in the spreadsheet.
            next if (scalar(@columns) == 0);

            # Lists of SQL names and values.
            my @sqlNames = ();
            my @sqlValues = ();

            # Process the columns in the record.
            for (my $j = 0; $j < scalar(@columns); $j++) {

                # Skip columns with the Death Rate, as this can be calculated.
                next if ( $columnLabels[$j] =~ m/Death Rate/ );

                # Get the database name for this column.
                my $column_label = $columnLabels[$j];
                push @sqlNames, $columnLabel_to_dbName{$column_label};

                # Get the data value for this cell.
                my $db_value = $columns[$j];

                # Special processing for month.
                if ($column_label eq 'Month') {
                    # Convert the month to lower-case.
                    $db_value =~ s/^.*$/\L$&/ ;
                    # Convert the month to a number.
                    $db_value = $month_as_number{$db_value};
                }

                # Special processing for region.
                elsif ($column_label eq 'Region') {
                    $db_value = $regionLabel_to_regionName{$db_value};
                }

                # Set empty fields to zero.
                elsif (length($db_value) == 0) {
                    $db_value = '0';
                }

                push @sqlValues, $db_value;

            }

            # Compose the SQL INSERT statement for this record.
            @sqlValues = map{$dbh->quote($_)} @sqlValues;

            my $sql = "INSERT into mortality ("
                . join(", ", @sqlNames)
                . ") VALUES ("
                . join(", ", @sqlValues)
                . ")";

            # Execute the SQL INSERT statement for this record.
            $dbh->do($sql);
        }

        # Disconnect from the database.
        $dbh->disconnect;

    }

# =================================================================

    # Update selected fields, using spreadsheet values.

    sub update_selected_fields($) {

        # Parameter: Spreadsheet filename (.csv file)
        my $spreadsheet_filename = shift;

        open SPREADSHEET, "<$spreadsheet_filename"
            or die "Cannot open CSV spreadsheet file: $!\n";

        my $csv = Text::CSV_XS->new();

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # Process the column headers for the spreadsheet,
        # which are in the first row of the spreadsheet.
        my $columnHeaderRow = <SPREADSHEET>;
        my $status = $csv->parse($columnHeaderRow);
        my @columnLabels = $csv->fields();

        # Process the records,
        # which are in the subsequent rows of the spreadsheet.
        while (<SPREADSHEET>) {

            # Extract the fields from this record.
            chomp $_;
            my $status = $csv->parse($_);
            my @columns = $csv->fields();

            # Skip empty rows in the spreadsheet.
            next if (scalar(@columns) == 0);

            # Lists of database names and values, from spreadsheet.
            my @sqlNames = ();
            my @sqlValues = ();

            # Process the columns in the record.
            for (my $j = 0; $j < scalar(@columns); $j++) {

                # Skip columns with the Death Rate, as this can be calculated.
                next if ( $columnLabels[$j] =~ m/Death Rate/ );

                # Get the database name for this column.
                my $column_label = $columnLabels[$j];
                push @sqlNames, $columnLabel_to_dbName{$column_label};

                # Get the data value for this cell.
                my $db_value = $columns[$j];

                # Special processing for month.
                if ($column_label eq 'Month') {
                    # Convert the month to lower-case.
                    $db_value =~ s/^.*$/\L$&/ ;
                    # Convert the month to a number.
                    $db_value = $month_as_number{$db_value};
                }

                # Special processing for region.
                elsif ($column_label eq 'Region') {
                    $db_value = $regionLabel_to_regionName{$db_value};
                }

                # Set empty fields to zero.
                elsif (length($db_value) == 0) {
                    $db_value = '0';
                }

                push @sqlValues, $db_value;

            }

            # Build the list of statistic name/value pairs to be updated
            # for this record.
            my @statNames = ();
            my @statValues = ();
            my $month = "";
            my $year = "";
            my $region = "";

            # Get the month, year, region, and statistics for this record.
            foreach my $db_name (@sqlNames) {

                if ($db_name eq 'month') {
                    $month = $dbh->quote(shift @sqlValues);
                }
                elsif ($db_name eq 'year') {
                    $year = $dbh->quote(shift @sqlValues);
                }
                elsif ($db_name eq 'region') {
                    $region = $dbh->quote(shift @sqlValues);
                }
                else {
                    # Statistic
                    push @statNames, $db_name;
                    push @statValues, shift @sqlValues;
                }
            }

            # Update each statistic in the database.
            foreach my $stat_name (@statNames) {

                # Get the corresponding statistic value.
                my $stat_value = $dbh->quote(shift @statValues);

                # Compose the SQL UPDATE statement for this record.
                my $sql = qq/
                    UPDATE mortality
                    SET ${stat_name} = ${stat_value}
                    WHERE month = ${month}
                    AND year = ${year}
                    AND region = ${region}
                    /;

                # Execute the SQL UPDATE statement for this record.
                $dbh->do($sql);
            }
        }

        # Disconnect from the database.
        $dbh->disconnect;

    }

# =================================================================

    # Add a new column to the INPUB database.

    sub add_column($) {

        # Parameter: New column name
        my $new_column_name = shift;

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # SQL statement to add column to table.
        my $sql = qq( ALTER TABLE mortality
            ADD ${new_column_name} VARCHAR(255)
        );

        my $status = $dbh->do($sql);

        # Disconnect from the database.
        $dbh->disconnect;

    }

# =================================================================

    # For MS Access: Set undefined (NULL) data to the default value.

    sub default_data() {

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # Get the column names.
        my $sth = $dbh->prepare("SELECT * FROM mortality");
        $sth->execute();
        my $pdb_column_names = $sth->{NAME};
        my @db_column_names = @$pdb_column_names;
        $sth->finish();

        # Default statistic value is "..."
        my $NA = $dbh->quote('...');

        foreach my $db_name (@db_column_names) {

            # Skip columns which must be non-NULL.
            next if ($db_name eq 'id');
            next if ($db_name eq 'month');
            next if ($db_name eq 'year');
            next if ($db_name eq 'region');

            # UPDATE all NULL values in the database
            my $sql = qq/
                UPDATE mortality
                SET ${db_name} = ${NA}
                WHERE ${db_name} IS NULL
                /;

            $dbh->do($sql);

        }

        # Disconnect from the database.
        $dbh->disconnect();

    }

# =================================================================

    sub delete_table() {

        # Connect to the INPUB database.
        my $dbh = inpub_connect('inpub');

        # DROP (delete) the table.
        my $sql = qq( DROP TABLE mortality; );
        my $status = $dbh->do($sql);

        # Disconnect from the database.
        $dbh->disconnect();
    }

# =================================================================

    sub inpub_connect($) {

        my $database = shift;

        # Connect to the SQLite database.
        my $dbh = DBI->connect(
            "dbi:SQLite:dbname=${database}.db", "", "");

        # Connect to the MySQL database.
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
