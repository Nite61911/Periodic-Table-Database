#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=periodic_table -c"

# Rename columns
$PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;"
$PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
$PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"

# Set NOT NULL constraints
$PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;"
$PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"

# Add unique constraints
$PSQL "ALTER TABLE elements ADD UNIQUE(symbol);"
$PSQL "ALTER TABLE elements ADD UNIQUE(name);"

# Set columns to NOT NULL
$PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;"
$PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;"

# Add foreign key
$PSQL "ALTER TABLE properties ADD FOREIGN KEY (atomic_number) REFERENCES elements(atomic_number);"

# Create types table
$PSQL "CREATE TABLE types(type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);"
$PSQL "INSERT INTO types(type) SELECT DISTINCT(type) FROM properties;"

# Add and update type_id in properties
$PSQL "ALTER TABLE properties ADD COLUMN type_id INT;"
$PSQL "ALTER TABLE properties ADD FOREIGN KEY(type_id) REFERENCES types(type_id);"
$PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE properties.type = types.type);"
$PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;"

# Standardize element symbols to Title Case
$PSQL "UPDATE elements SET symbol=INITCAP(symbol);"

# Modify atomic_mass to a float type and update values
$PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE VARCHAR(9);"
$PSQL "UPDATE properties SET atomic_mass=CAST(atomic_mass AS FLOAT);"

# Insert new elements and properties
$PSQL "INSERT INTO elements(atomic_number,symbol,name) VALUES(9,'F','Fluorine');"
$PSQL "INSERT INTO properties(atomic_number,type,melting_point_celsius,boiling_point_celsius,type_id,atomic_mass) VALUES(9,'nonmetal',-220,-188.1,3,'18.998');"
$PSQL "INSERT INTO elements(atomic_number,symbol,name) VALUES(10,'Ne','Neon');"
$PSQL "INSERT INTO properties(atomic_number,type,melting_point_celsius,boiling_point_celsius,type_id,atomic_mass) VALUES(10,'nonmetal',-248.6,-246.1,3,'20.18');"

# Delete placeholder data
$PSQL "DELETE FROM properties WHERE atomic_number=1000;"
$PSQL "DELETE FROM elements WHERE atomic_number=1000;"

# Drop the type column in properties
$PSQL "ALTER TABLE properties DROP COLUMN type;"
