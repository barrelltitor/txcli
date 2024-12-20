# txCLI: The txAdmin Recipe Automation Tool

**txCLI** is a lightweight Bash script, also available as a Docker image, designed to automate the deployment of txAdmin recipes for FiveM servers. It parses recipe files and executes the actions defined within them. Can be used to automate the deployment of fivem recipes on Pterodactyl, or in any environment.

Currently it will setup the recipe in /mnt/server, but that is configurable from within the script. 

## Usage

### Bash
txcli uses environment variables to pass on the required values. Once you set these, simply run the script.

```bash
export RECIPE=https://raw.githubusercontent.com/esx-framework/esx-recipes/refs/heads/legacy/recipe.yaml
export DB=mysql://user:password@host/database
export INSTALL_PATH=/mnt/server

bash /path/to/txcli.sh
```

### Docker 

```bash
RECIPE=https://raw.githubusercontent.com/esx-framework/esx-recipes/refs/heads/legacy/recipe.yaml
DB=mysql://user:password@host/database
INSTALL_PATH=/mnt/server
docker run --rm -it \
    -v ./:/mnt/server \
    -e DB_CONN_STR="$DB" \
    -e RECIPE_URL="$RECIPE" \
    -e INSTALL_PATH="$INSTALL_PATH" \
    ghcr.io/barrelltitor/txcli
```

## Features

- It can install any recipe as it replicates all txadmin actions in bash functions
- Imports the necessary sql files in the provided database (currently required)
- Support custom installation paths 
- Docker ready
- Quick and helpful developer ready to implement other needed features

## License

You can't own lines of bash. Do whatever you want with it, just give me proper credits if it's useful to you.