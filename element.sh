#!/bin/bash

# Database connection parameters
PSQL="psql -X --username=freecodecamp --dbname=periodic_table --tuples-only -c"

# Main function to handle user input and display element information
main() {
  # Check if the user provided an argument
  if [[ -z $1 ]]; then
    echo "Please provide an element symbol or atomic number as an argument."
    exit 1
  fi

  # Call the function to print the element details
  print_element_info "$1"
}

# Function to retrieve and print information about an element
print_element_info() {
  local input="$1"
  
  # Determine if the input is atomic number or symbol/name
  if [[ $input =~ ^[0-9]+$ ]]; then
    # Input is atomic number
    atomic_number="$input"
  else
    # Input is symbol or name, fetch the atomic number
    atomic_number=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE symbol='$input' OR name='$input';") | xargs)
  fi
  
  # Check if the atomic number was found
  if [[ -z $atomic_number ]]; then
    echo "I could not find that element in the database."
    exit 1
  fi

  # Fetch element details
  local name symbol atomic_mass melting_point boiling_point type_id
  name=$(echo $($PSQL "SELECT name FROM elements WHERE atomic_number=$atomic_number;") | xargs)
  symbol=$(echo $($PSQL "SELECT symbol FROM elements WHERE atomic_number=$atomic_number;") | xargs)
  atomic_mass=$(echo $($PSQL "SELECT atomic_mass FROM properties WHERE atomic_number=$atomic_number;") | xargs)
  melting_point=$(echo $($PSQL "SELECT melting_point_celsius FROM properties WHERE atomic_number=$atomic_number;") | xargs)
  boiling_point=$(echo $($PSQL "SELECT boiling_point_celsius FROM properties WHERE atomic_number=$atomic_number;") | xargs)
  type_id=$(echo $($PSQL "SELECT type_id FROM properties WHERE atomic_number=$atomic_number;") | xargs)
  type=$(echo $($PSQL "SELECT type FROM types WHERE type_id=$type_id;") | xargs)

  # Display the element information
  echo "The element with atomic number $atomic_number is $name ($symbol)."
  echo "It's classified as a $type, with a mass of $atomic_mass amu."
  echo "$name has a melting point of $melting_point °C and a boiling point of $boiling_point °C."
}

# Function to fix database schema issues
fix_database() {
  echo "Starting database fix..."

  # Rename columns in properties table for clarity
  echo "Renaming columns in properties table..."
  $PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;"
  $PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
  $PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"

  # Set NOT NULL constraints
  echo "Setting NOT NULL constraints on melting and boiling points..."
  $PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;"
  $PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"

  # Add UNIQUE constraints for element symbols and names
  echo "Adding UNIQUE constraints to symbol and name..."
  $PSQL "ALTER TABLE elements ADD UNIQUE(symbol);"
  $PSQL "ALTER TABLE elements ADD UNIQUE(name);"

  # Ensure that symbol and name are NOT NULL
  echo "Ensuring symbol and name columns are NOT NULL..."
  $PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;"
  $PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;"

  # Create types table with foreign keys
  echo "Creating types table and linking properties..."
  $PSQL "CREATE TABLE types(type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);"
  $PSQL "INSERT INTO types(type) SELECT DISTINCT(type) FROM properties;"
  $PSQL "ALTER TABLE properties ADD COLUMN type_id INT;"
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY(type_id) REFERENCES types(type_id);"

  # Update properties with the correct type_id
  echo "Updating properties with correct type IDs..."
  $PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE properties.type = types.type);"
  $PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;"

  # Capitalize symbols and adjust atomic_mass formatting
  echo "Capitalizing symbols in elements table..."
  $PSQL "UPDATE elements SET symbol=INITCAP(symbol);"
  echo "Adjusting atomic_mass formatting..."
  $PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE VARCHAR(9);"
  $PSQL "UPDATE properties SET atomic_mass=CAST(atomic_mass AS FLOAT);"

  # Insert new elements into the database
  echo "Inserting new elements (Fluorine and Neon)..."
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES(9, 'F', 'Fluorine');"
  $PSQL "INSERT INTO properties(atomic_number, type, melting_point_celsius, boiling_point_celsius, type_id, atomic_mass) VALUES(9, 'nonmetal', -220, -188.1, 3, '18.998');"
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES(10, 'Ne', 'Neon');"
  $PSQL "INSERT INTO properties(atomic_number, type, melting_point_celsius, boiling_point_celsius, type_id, atomic_mass) VALUES(10, 'nonmetal', -248.6, -246.1, 3, '20.18');"

  # Clean up non-existent elements and drop unnecessary columns
  echo "Removing non-existent elements..."
  $PSQL "DELETE FROM properties WHERE atomic_number=1000;"
  $PSQL "DELETE FROM elements WHERE atomic_number=1000;"
  echo "Dropping obsolete type column from properties table..."
  $PSQL "ALTER TABLE properties DROP COLUMN type;"

  echo "Database fix completed successfully."
}

# Start the program
if [[ $(echo $($PSQL "SELECT COUNT(*) FROM elements WHERE atomic_number=1000;")) -gt 0 ]]; then
  fix_database
  echo "Database schema was fixed. You can now query elements."
fi

# Execute the main function with user input
main "$1"
