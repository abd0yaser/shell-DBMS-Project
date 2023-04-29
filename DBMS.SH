#!/bin/bash

create_database() {

    read -p "Enter  name of db: " dbname
    if [ -d "$dbname" ]; then
        echo "Db '$dbname' already exists."
      else 
        mkdir  "$dbname"

        fi 
      

    # Create the metadata file
    cat << EOF > "$dbname/.metadata"
name=$dbname
created=$(date)
EOF

    echo "Database '$dbname' created successfully."
}

list_databases() {
    echo "list of db"
   echo "----------------------------------"

   ls -d */

   }

drop_database() {
    
     echo "enter db name :  "
     read  dbname
     if [ -d $dbname ]; then
    rm -r $dbname
     echo "db drope done"
    else
     echo "db doesnot exist"
     fi

     }
     
create_table() {
   # Prompt the user for the table name
    read -p "Enter the name of the new table: " tablename

    # Check if the table already exists
    if [ -f "$dbname/$tablename" ]; then
        echo "Error: Table '$tablename' already exists."
        return 1
    fi

    # Create the new table file
    touch "$dbname/$tablename"

    # Prompt the user for the data type of the primary key column
    read -p "Enter the data type of the primary key column (string or integer): " pk_type
    if [ "$pk_type" != "string" ] && [ "$pk_type" != "integer" ]; then
        echo "Error: Invalid primary key data type '$pk_type'. Primary key data type must be 'string' or 'integer'."
        rm "$dbname/$tablename"
        return 1
    fi

    # Prompt name of pk column
    read -p "Enter the name of the primary key column: " pk_id
    if [ "$pk_type" == "integer" ] && ! [[ "$pk_id" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid primary key ID '$pk_id'. Primary key ID must be an integer."
        rm "$dbname/$tablename"
        return 1
    fi

    # Prompt the user for the number of columns
    read -p "Enter the number of columns (excluding the primary key column): " num_cols

    # Loop through each column and prompt for its name and datatype
    columns="$pk_id $pk_type"
    for (( i=1; i<=$num_cols; i++ )); do
        read -p "Enter the name of column $i: " col_name
        read -p "Enter the datatype of column $i (string or integer): " col_type
        if [ "$col_type" != "string" ] && [ "$col_type" != "integer" ]; then
            echo "Error: Invalid column datatype '$col_type'. Column datatype must be 'string' or 'integer'."
            rm "$dbname/$tablename"
            return 1
        fi
        columns="$columns,$col_name $col_type"
    done

    # Create the table schema in the metadata file
    cat << EOF > "$dbname/.${tablename}.metadata"
name=$tablename
columns=$columns
EOF

    echo "Table '$tablename' created successfully."
}

list_tables() {
    if [ ! -d "$1" ]; then
        echo "Error: Database '$1' does not exist."
        return 1
    fi

    echo "List of tables:"
    echo "---------------"
   for table in "$1"/*; do
        if [ -f "$table" ] && [ "$(basename "$table")" != ".metadata" ]; then
            echo "$(basename "$table")"
        fi
    done
}

function drop_table() {
  # Check that a database name was provided
  if [ -z "$1" ]; then
    echo "Please provide the name of the database."
    return 1
  fi

  # Check that the database exists
  if ! [ -d "./$1" ]; then
    echo "Database '$1' does not exist."
    return 1
  fi

  # Prompt the user for the name of the table to drop
  read -p "Enter the name of the table you want to drop: " table_name

  # Check that the table exists
  if ! [ -f "./$1/$table_name" ]; then
    echo "Table '$table_name' does not exist in database '$1'."
    return 1
  fi

  # Drop the table
  rm "./$1/$table_name"
  rm "./$1/.$table_name.metadata"
  echo "Table '$table_name' was dropped from database '$1'."
}

update_table() {


    # Prompt the user for the table name
    read -p "Enter the name of the table: " tablename

    # Check if the table exists
    if [ ! -f "$dbname/$tablename" ]; then
        echo "Error: Table '$tablename' does not exist."
        return 1
    fi

    # Read the metadata file to get the column names
    columns=$(sed -n '2p' "$dbname/.$tablename.metadata")
    IFS=',' read -ra column_array <<< "$columns"

    # Prompt the user for the primary key value of the record to update
    read -p "Enter the primary key value of the record to update: " pk_value

    # Check if the record exists
    if ! grep -q "^$pk_value\b" "$dbname/$tablename"; then
        echo "Error: Record with primary key value '$pk_value' does not exist."
        return 1
    fi

    # Prompt the user for the column to update
    echo "Available columns:"
    for i in "${!column_array[@]}"; do
        echo "$(($i+1)). ${column_array[$i]}"
    done
    read -p "Enter the number of the column to update: " col_num

    # Check if the column number is valid
    if (( col_num < 1 || col_num > ${#column_array[@]} )); then
        echo "Error: Invalid column number."
        return 1
    fi

    # Get the column name and prompt the user for the new value
    col_name="${column_array[$((col_num-1))]}"
    read -p "Enter the new value for column '$col_name': " new_value

    # Update the record

   #     sed -i "s/^$pk_value\s\+\(\S\+\)\(\s\+\S\+\)\{,$((col_num-1))\}\s*\(\S\+\)\?/\1 ${new_value}/" "$dbname/$tablename"
   #     sed -i "s/^\($pk_value\s\+\S\+\)\(\s\+\S\+\)\{,$((col_num-1))\}\s*\S*\s*/\1${column_array[@]/$col_name/}$new_value /" "$dbname/$tablename"
          sed -i "s/^$pk_value\s\+\(\S\+\)\s\+\(\S\+\)\s*/$pk_value $new_value \2/" "$dbname/$tablename"

         echo "Record with primary key value '$pk_value' updated successfully."

}


insert_into_table() {
    # Prompt the user for the table name
    read -p "Enter the name of the table to insert into: " tablename

    # Check if the table exists
    if [ ! -f "$dbname/$tablename" ]; then
        echo "Error: Table '$tablename' does not exist."
        return 1
    fi

    # Read the columns from the metadata file
    columns=$(awk -F= '/^columns=/{print $2}' "$dbname/.${tablename}.metadata")

    # Check if there are any columns in the table
    if [ -z "$columns" ]; then
        echo "Error: Table '$tablename' has no columns defined."
        return 1
    fi

    # Create an array of column names and types
    IFS=',' read -ra column_array <<< "$columns"
    num_cols=${#column_array[@]}
    declare -a col_names
    declare -a col_types
    for (( i=1; i<=$num_cols; i++ )); do
        col=$(echo "${column_array[$i]}" | tr -d ' ')
        col_names[$i]=$(echo "$col" | cut -d' ' -f1)
        col_types[$i]=$(echo "$col" | cut -d' ' -f2)
        if [ "${col_names[$i]}" == "Id" ]; then
            id_index=$i
        fi
    done

    # Read the existing primary keys from the table
    declare -a primary_keys
    while read -r row; do
        primary_keys+=($(echo "$row" | cut -d',' -f$((id_index+1))))

    done < "$dbname/$tablename"

  # Create an array of values to insert
declare -a values


for (( i=0; i<=$num_cols-1; i++ )); do
    if [ $i -eq 0 ]; then
        read -p "Enter the value for column 'Id': " value
    else
        read -p "Enter the value for column '${col_names[$i]}': " value
    fi
    # Check if the value is of the correct datatype
    if [ "${col_types[$i]}" == "integer" ]; then
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            echo "Error: Value for column '${col_names[$i]}' must be an integer."
            return 1
        fi
    fi
    values[$i]="$value"
done


    # Check if the primary key already exists
    if [[ "${primary_keys[*]}" =~ "${values[$id_index]}" ]]; then
        echo "Error: Value for primary key 'Id' already exists."
        return 1
    fi

    # Insert the values into the table
    echo "${values[*]}" >> "$dbname/$tablename"

    echo "Values inserted into table '$tablename' successfully."
}



select_data() {
    echo "Enter table name: "
    read table_name
    if [[ -f "$dbname/$table_name" ]]; then
        # print table header
        arr=()
        test=$(cat "$dbname/.$table_name.metadata" | cut -d "=" -f2)
        local IFS=","
        for variable in $test; do
            arr+=("$(cut -d ' ' -f1 <<<"$variable")")
        done
        echo "${arr[*]}" | sed 's/ /,/g'

        # print table data
        cat "$dbname/$table_name"
    else
        echo "Table does not exist"
    fi
}





delete_data() {

 
    # Check that a database name, table name, and ID were provided
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "Please provide the name of the database, table, and ID."
        return 1
    fi

    # Check that the database and table exist
    if ! [ -d "./$1" ]; then
        echo "Database '$1' does not exist."
        return 1
    fi
    if ! [ -f "./$1/$2" ]; then
        echo "Table '$2' does not exist in database '$1'."
        return 1
    fi

    # Delete the row with the corresponding ID
    NR=`awk 'BEGIN{FS=" "}{if ($1=="'$3'") print NR}' "./$1/$2"`
    sed -i ''$NR'd' "./$1/$2"

    echo "Row with ID '$3' deleted from table '$2' in database '$1'."
   
}



connect_to_database() {
    echo "Enter the name of the db  to connect to: "
    read dbname

    if [[ ! -d "$dbname" ]]; then
        echo " Db $dbname does not exist."

    fi


    echo "Connected to database >> $dbname"
    while true; do
        echo "Menu:"
        echo "1. Create Table"
        echo "2. List Tables"
        echo "3. Drop Table"
        echo "4. Insert Data"
        echo "5. Select Data"
        echo "6. delete Data"
        echo "7. update Data"
        echo "8. Back to Main Menu"
        read -p "Enter your choice: " choice

        case "$choice" in
            1)
                create_table "$dbname"
                ;;
            2)
                list_tables "$dbname"
                ;;
            3)
                drop_table "$dbname" 
                ;;
            4)
                insert_into_table "$dbname"
                ;;
            5)
                select_data "$dbname"
                ;;
            6)   echo "Enter the table name to Delete from"
                 read Table_name
                 echo "Enter the ID "
                 read Id
                delete_data "$dbname" $Table_name $Id
                ;;    
            7)  
                 update_table "$dbname" $Id
                ;;        
            8)
                return 0
                #Main_Menu
                ;;
            *)
                echo "Invalid choice. Please try again."
                ;;
        esac
    done
}


Main_Menu(){
while true; do
    echo "Main Menu:"
    echo "1. Create Database"
    echo "2. List Databases"
    echo "3. Drop Databases"
    echo "4. Connect To Databases"
    echo "5. Exit"
    read -p "Enter your choice: " choice

    case "$choice" in
        1)
            create_database
            ;;
        2)
            list_databases
            ;;
        3)
            drop_database
            ;;
        4)
            connect_to_database
            ;;     
                
        5)
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
}

Main_Menu
