#!/bin/bash

check_dependencies() {
  for cmd in curl git unzip yq mysql wget; do
    if ! command -v $cmd &>/dev/null; then
      echo "Error: $cmd is not installed. Please install it before running the script."
      exit 1
    fi
  done
}

cleanup() {
  if [[ -d "./tmp" ]]; then
    rm -rf "./tmp" "./temp_repo"
    rm -f "./recipe.yaml"
  fi
}
trap cleanup EXIT

download_github() {
  local src=$1
  local ref=$2
  local subpath=$3
  local dest=$4

  echo "Downloading GitHub repo: $src"

  # Clone the repository, handling the case where ref is "null" or empty
  if [[ -z "$ref" || "$ref" == "null" ]]; then
    git clone --depth 1 "$src" temp_repo || {
      echo "Error: Failed to clone $src"
      exit 1
    }
  else
    git clone --depth 1 --branch "$ref" "$src" temp_repo || {
      echo "Error: Failed to clone $src with branch $ref"
      exit 1
    }
  fi

  mkdir -p "$(dirname "$dest")"

  # Handle subpath if specified
  if [[ -n $subpath && $subpath != "null" ]]; then
    mv "temp_repo/$subpath" "$dest" || {
      echo "Error: Failed to move $subpath to $dest"
      exit 1
    }
  else
    # Move the entire repository if no subpath is specified
    mv temp_repo "$dest" || {
      echo "Error: Failed to move repository to $dest"
      exit 1
    }
  fi
  rm -rf temp_repo
}



download_file() {
  local url=$1
  local path=$2

  echo "Downloading file from: $url"
  mkdir -p "$(dirname "$path")"
  curl -L -o "$path" "$url" || {
    echo "Error: Failed to download $url"
    exit 1
  }
}

unzip_file() {
  local src=$1
  local dest=$2

  echo "Unzipping $src to $dest"
  mkdir -p "$dest"
  unzip -o "$src" -d "$dest" || {
    echo "Error: Failed to unzip $src"
    exit 1
  }
}

# Function to move a path
move_path() {
  local src=$1
  local dest=$2

  echo "Moving $src to $dest"
  mv "$src" "$dest" || {
    echo "Error: Failed to move $src to $dest"
    exit 1
  }
}

copy_path() {
  local src=$1
  local dest=$2

  echo "Copying $src to $dest"
  cp -r "$src" "$dest" || {
    echo "Error: Failed to copy $src to $dest"
    exit 1
  }
}

remove_path() {
  local path=$1

  echo "Removing $path"
  rm -rf "$path" || {
    echo "Error: Failed to remove $path"
    exit 1
  }
}


ensure_dir() {
  local dir=$1

  echo "Ensuring directory exists: $dir"
  mkdir -p "$dir" || {
    echo "Error: Failed to create directory $dir"
    exit 1
  }
}

write_file() {
  local path=$1
  local content=$2

  echo "Writing to file: $path"
  echo -e "$content" >"$path" || {
    echo "Error: Failed to write to $path"
    exit 1
  }
}


replace_string() {
  local file=$1
  local search=$2
  local replace=$3

  echo "Replacing '$search' with '$replace' in $file"
  sed -i "s|$search|$replace|g" "$file" || {
    echo "Error: Failed to replace string in $file"
    exit 1
  }
}

load_vars() {
  local file=$1

  echo "Loading variables from $file"
  if [[ ! -f $file ]]; then
    echo "Error: Variable file not found: $file"
    exit 1
  fi

  set -o allexport
  source "$file"
  set -o noallexport
}


connect_database() {
  if [[ -z "$DB_CONN_STR" ]]; then
    echo "Error: DB_CONN_STR environment variable not set"
    exit 1
  fi

  # Parse DB_CONN_STR in the format mysql://user:password@host:port/database
  local user=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $4}')
  local password=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $5}')
  local host=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $6}')
  local port=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $7}')
  local database=$(echo "$DB_CONN_STR" | awk -F'/' '{print $4}')
  
  if [[ -z "$user" || -z "$password" || -z "$host" || -z "$port" || -z "$database" ]]; then
    echo "Error: Invalid DB_CONN_STR format. found $user <user $password < pass $host <host $port < port $database < db"
    echo "The full str was $DB_CONN_STR"
    exit 1
  fi

  echo "Testing database connection to $host:$port as $user..."
  mysql --host="$host" --port="$port" --user="$user" --password="$password" --database="$database" -e "SELECT 1;" || {
    echo "Error: Failed to connect to the database"
    exit 1
  }
  echo "Database connection successful"
}



query_database() {
  local file=$1

  if [[ -z "$DB_CONN_STR" ]]; then
    echo "Error: DB_CONN_STR environment variable not set"
    exit 1
  fi

  # Parse DB_CONN_STR in the format mysql://user:password@host:port/database
  local user=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $4}')
  local password=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $5}')
  local host=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $6}')
  local port=$(echo "$DB_CONN_STR" | awk -F'[/:@]' '{print $7}')
  local database=$(echo "$DB_CONN_STR" | awk -F'/' '{print $4}')

  echo "Executing SQL file: $file on $database@$host:$port as $user"
  mysql --host="$host" --port="$port" --user="$user" --password="$password" --database="$database" < "$file" || {
    echo "Error: Failed to execute SQL file $file"
    exit 1
  }
}

# Function to waste time (prevent GitHub throttling)
waste_time() {
  local seconds=$1

  echo "Waiting for $seconds seconds..."
  sleep "$seconds"
}
finalize_server_config() {
  local server_cfg="./server.cfg"
  local recipe_name
  local recipe_description
  local onesync

  recipe_name=$(yq eval '.name' "$recipe_file")
  recipe_description=$(yq eval '.description' "$recipe_file")
  onesync=$(yq eval '.onesync' "$recipe_file")


  recipe_name=${recipe_name:-"Unknown Recipe"}
  recipe_description=${recipe_description:-"No description available"}

  echo "Finalizing server.cfg with:"
  echo "  Recipe Name: $recipe_name"
  echo "  Recipe Description: $recipe_description"
  echo "  OneSync Enabled: $onesync"

  if [[ ! -f $server_cfg ]]; then
    echo "Error: $server_cfg not found."
    exit 1
  fi

 
  sed -i "s/{{maxClients}}/48/g" "$server_cfg"
  sed -i "s|{{dbConnectionString}}|$DB_CONN_STR|g" "$server_cfg"
  sed -i "s|{{recipeName}}|$recipe_name|g" "$server_cfg"
  sed -i "s|{{recipeDescription}}|$recipe_description|g" "$server_cfg"
  sed -i "s|{{serverName}}|Server Name|g" "$server_cfg"
  sed -i "s|{{svLicense}}|changeme|g" "$server_cfg"
  sed -i "s|{{serverEndpoints}}|endpoint_add_tcp \"0.0.0.0:30120\"\nendpoint_add_udp \"0.0.0.0:30120\"|g" "$server_cfg"

  # Handle onesync setting
  if [[ "$onesync" == "on" ]]; then
    sed -i "/{{recipeDescription}}/a set onesync on" "$server_cfg"
  fi

  # Replace addPrincipalsMaster with updated value
  sed -i "s|{{addPrincipalsMaster}}|add_principal identifier.fivem:1 group.admin|g" "$server_cfg"

  echo "server.cfg finalized."
}


# Process the recipe file
process_recipe() {
  local recipe_file=$1

  echo "Processing recipe: $recipe_file"
  mkdir -p ./tmp
  mkdir -p ./resources
  actions=$(yq eval '.tasks' "$recipe_file")
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to parse recipe file"
    exit 1
  fi

  # Loop through actions
  for index in $(seq 0 $(($(yq eval '.tasks | length' "$recipe_file") - 1))); do
    local action=$(yq eval ".tasks[$index]" "$recipe_file")
    local type=$(yq eval ".tasks[$index].action" "$recipe_file")

    case $type in
    download_github)
      download_github \
        "$(yq eval ".tasks[$index].src" "$recipe_file")" \
        "$(yq eval ".tasks[$index].ref" "$recipe_file")" \
        "$(yq eval ".tasks[$index].subpath" "$recipe_file")" \
        "$(yq eval ".tasks[$index].dest" "$recipe_file")"
      ;;
    download_file)
      download_file \
        "$(yq eval ".tasks[$index].url" "$recipe_file")" \
        "$(yq eval ".tasks[$index].path" "$recipe_file")"
      ;;
    unzip)
      unzip_file \
        "$(yq eval ".tasks[$index].src" "$recipe_file")" \
        "$(yq eval ".tasks[$index].dest" "$recipe_file")"
      ;;
    move_path)
      move_path \
        "$(yq eval ".tasks[$index].src" "$recipe_file")" \
        "$(yq eval ".tasks[$index].dest" "$recipe_file")"
      ;;
    copy_path)
      copy_path \
        "$(yq eval ".tasks[$index].src" "$recipe_file")" \
        "$(yq eval ".tasks[$index].dest" "$recipe_file")"
      ;;
    remove_path)
      remove_path "$(yq eval ".tasks[$index].path" "$recipe_file")"
      ;;
    ensure_dir)
      ensure_dir "$(yq eval ".tasks[$index].path" "$recipe_file")"
      ;;
    write_file)
      write_file "$(yq eval ".tasks[$index].path" "$recipe_file")" "$(yq eval ".tasks[$index].content" "$recipe_file")"
      ;;
    replace_string)
      replace_string "$(yq eval ".tasks[$index].file" "$recipe_file")" "$(yq eval ".tasks[$index].search" "$recipe_file")" "$(yq eval ".tasks[$index].replace" "$recipe_file")"
      ;;
    load_vars)
      load_vars "$(yq eval ".tasks[$index].file" "$recipe_file")"
      ;;
    connect_database)
      connect_database
      ;;
    query_database)
      query_database "$(yq eval ".tasks[$index].file" "$recipe_file")"
      ;;
    waste_time)
      waste_time "$(yq eval ".tasks[$index].seconds" "$recipe_file")"
      ;;
    *)
      echo "Warning: Unknown action type: $type"
      ;;
    esac
  done
  finalize_server_config
  rm -f recipe.yaml
  
}

if [[ -z "$RECIPE_URL" ]]; then
  echo "Error: RECIPE_URL environment variable not set."
  exit 1
fi
INSTALL_PATH=${INSTALL_PATH:-/mnt/server}
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH" || exit 1
recipe_file="recipe.yaml"
wget -O "$recipe_file" "$RECIPE_URL"

if [[ ! -f $recipe_file ]]; then
  echo "Recipe file not found: $recipe_file"
  exit 1
fi

check_dependencies
process_recipe "$recipe_file"
