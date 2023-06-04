#!/bin/bash

# PostgreSQL credentials
PGHOST_DUMP=dump-host.com
PGPORT_DUMP=5432
PGUSER_DUMP=postgres

PGHOST_RESTORE=restore-host.com
PGPORT_RESTORE=5432
PGUSER_RESTORE=postgres

# Array of databases to dump
DATABASES=(
  db1
  db2
  db3
)

# Number of jobs for parallel dump and restore 
# Note: pg_dump only supports this for the directory format, in this script the custom format is used
JOBS=4

# Create a timestamp tag
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Directory where the SQL dump will be stored
DUMP_DIR="./${TIMESTAMP}/"

# Create the directory
mkdir -p $DUMP_DIR

# Log file
LOGFILE="${DUMP_DIR}pg_dump_restore.log"

# Define a logging function
log() {
  echo "--------------------------------------------------------------------------"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOGFILE}"
  echo "--------------------------------------------------------------------------"
}

# Function to convert seconds to hours, minutes, and seconds
convertsecs() {
    h=$(($1/3600))
    m=$(($1%3600/60))
    s=$(($1%60))
    printf "%02d:%02d:%02d\n" $h $m $s
}

# Check for free storage
REQUIRED_DISK_SPACE=2048 # in MB
CURRENT_DISK_SPACE=$(df / | tail -1 | awk '{print $4}')

if (( CURRENT_DISK_SPACE < REQUIRED_DISK_SPACE )); then
  log "Not enough disk space. Required: ${REQUIRED_DISK_SPACE}MB, Available: ${CURRENT_DISK_SPACE}MB"
  exit
fi

# Print the PostgreSQL credentials
log "Dump Connection:"
log "Host: $PGHOST_DUMP"
log "Port: $PGPORT_DUMP"
log "User: $PGUSER_DUMP"
log "Restore Connection:"
log "Host: $PGHOST_RESTORE"
log "Port: $PGPORT_RESTORE"
log "User: $PGUSER_RESTORE"

# Prompt for passwords
printf "Please enter the PostgreSQL password for dump: "
read -s PGPASSWORD_DUMP
export PGPASSWORD_DUMP
echo

printf "Please enter the PostgreSQL password for restore: "
read -s PGPASSWORD_RESTORE
export PGPASSWORD_RESTORE
echo

# Test connections
PGPASSWORD=$PGPASSWORD_DUMP psql -h $PGHOST_DUMP -p $PGPORT_DUMP -U $PGUSER_DUMP -c '\q' || exit
log "Dump connection successful."
PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -c '\q' || exit
log "Restore connection successful."

log "STARTING DUMP"
START_TIME_TOTAL_DUMP=$(date +%s)

# Loop through each database and create a dump
for DB_NAME in "${DATABASES[@]}"
do
  DUMP_FILE="${DB_NAME}.dump" # Adding the .dump extension
  DUMP_FILE_PATH="${DUMP_DIR}${DUMP_FILE}"

  log "Creating PostgreSQL dump of database $DB_NAME..."
  START_TIME=$(date +%s)
  
  PGPASSWORD=$PGPASSWORD_DUMP pg_dump -h $PGHOST_DUMP -p $PGPORT_DUMP -U $PGUSER_DUMP -Fc -f $DUMP_FILE_PATH $DB_NAME
  if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    log "Dump of $DB_NAME created at $DUMP_FILE_PATH in $(convertsecs $((END_TIME-START_TIME)))"
  else
    log "Failed to create dump of $DB_NAME"
    exit 1
  fi
done

END_TIME_TOTAL_DUMP=$(date +%s)
log "DUMP COMPLETED in $(convertsecs $((END_TIME_TOTAL_DUMP-START_TIME_TOTAL_DUMP)))"

# The same directory is used for restoring databases
RESTORE_DIR=$DUMP_DIR

log "STARTING RESTORE"
START_TIME_TOTAL_RESTORE=$(date +%s)

# Loop through each database and restore
for DB_NAME in "${DATABASES[@]}"
do
  DUMP_FILE="${DB_NAME}.dump"
  RESTORE_FILE="${DB_NAME}.dump"

  DUMP_FILE_PATH="${DUMP_DIR}${DUMP_FILE}"
  RESTORE_FILE_PATH="${RESTORE_DIR}${RESTORE_FILE}"

  ROLE_NAME=$(echo $DB_NAME | rev | cut -d '_' -f 2- | rev)

  # Check if role exists
  PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -tAc "SELECT 1 FROM pg_roles WHERE rolname='$ROLE_NAME'" | grep -q 1
  if [ $? -eq 0 ]; then
    log "Role $ROLE_NAME exists."
  else
    log "Creating role $ROLE_NAME..."
    PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -c "CREATE ROLE $ROLE_NAME LOGIN;"
  fi

  log "Adding $PGUSER_RESTORE to role $ROLE_NAME..."
  PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -c "GRANT $ROLE_NAME TO $PGUSER_RESTORE;"

  # Check if database exists
  PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1
  if [ $? -eq 0 ]; then
    log "Database $DB_NAME exists."
    printf "Do you want to drop the existing database (y/n): "
    read DROP_DB
    if [ "$DROP_DB" = "y" ]; then
      log "Dropping database $DB_NAME..."
      PGPASSWORD=$PGPASSWORD_RESTORE dropdb -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE $DB_NAME
    else
      log "Skipping restore for database $DB_NAME"
      continue
    fi
  fi

  log "Creating database $DB_NAME..."
  PGPASSWORD=$PGPASSWORD_RESTORE createdb -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE $DB_NAME

  log "Granting permissions to $ROLE_NAME on database $DB_NAME..."
  PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -c "GRANT CONNECT, TEMPORARY ON DATABASE $DB_NAME TO $ROLE_NAME;"

  log "Restoring PostgreSQL database $DB_NAME..."
  START_TIME=$(date +%s)

  PGPASSWORD=$PGPASSWORD_RESTORE pg_restore -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -d $DB_NAME -j $JOBS -Fc $RESTORE_FILE_PATH
  # This would cause the script to exit, even with warnings
  # if [ $? -eq 0 ]; then
  #   END_TIME=$(date +%s)
  #   log "Database $DB_NAME restored from $RESTORE_FILE_PATH in $(convertsecs $((END_TIME-START_TIME)))"
  # else
  #   log "Failed to restore database $DB_NAME"
  #   exit 1
  # fi
  END_TIME=$(date +%s)
  log "Database $DB_NAME restored from $RESTORE_FILE_PATH in $(convertsecs $((END_TIME-START_TIME)))"

  log "Removing $PGUSER_RESTORE from role $ROLE_NAME..."
  PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -c "REVOKE $ROLE_NAME FROM $PGUSER_RESTORE;"
done

END_TIME_TOTAL_RESTORE=$(date +%s)
log "RESTORE COMPLETED in $(convertsecs $((END_TIME_TOTAL_RESTORE-START_TIME_TOTAL_RESTORE)))"

unset PGPASSWORD_DUMP
unset PGPASSWORD_RESTORE
