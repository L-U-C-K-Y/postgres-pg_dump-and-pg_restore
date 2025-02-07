#!/bin/bash

# PostgreSQL credentials
PGHOST_RESTORE=restore-host.com
PGPORT_RESTORE=5432
PGUSER_RESTORE=postgres

# Array of databases to restore
DATABASES=(
  db1
  db2
  db3
)

# Parallel jobs for restore
JOBS=4

# Directory containing dumps
RESTORE_DIR=$1
if [ -z "$RESTORE_DIR" ]; then
  echo "Usage: $0 <dump_directory>"
  exit 1
fi

LOGFILE="${RESTORE_DIR}pg_restore.log"

# Logging function
log() {
  echo "--------------------------------------------------------------------------"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOGFILE}"
  echo "--------------------------------------------------------------------------"
}

convertsecs() {
    h=$(($1/3600))
    m=$(($1%3600/60))
    s=$(($1%60))
    printf "%02d:%02d:%02d\n" $h $m $s
}

# Print connection info
log "Restore Connection:"
log "Host: $PGHOST_RESTORE"
log "Port: $PGPORT_RESTORE"
log "User: $PGUSER_RESTORE"

# Get password
printf "Please enter the PostgreSQL password for restore: "
read -s PGPASSWORD_RESTORE
export PGPASSWORD_RESTORE
echo

# Test connection
PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -d postgres -c '\q' || exit 1
log "Restore connection successful."

log "STARTING RESTORE"
START_TIME_TOTAL_RESTORE=$(date +%s)

# Restore databases
for DB_NAME in "${DATABASES[@]}"
do
  RESTORE_FILE="${DB_NAME}.dump"
  RESTORE_FILE_PATH="${RESTORE_DIR}${RESTORE_FILE}"

  # Create role name
  ROLE_NAME=$(echo $DB_NAME | rev | cut -d '_' -f 2- | rev)

  # Check/create role
  PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -tAc "SELECT 1 FROM pg_roles WHERE rolname='$ROLE_NAME'" | grep -q 1
  if [ $? -eq 0 ]; then
    log "Role $ROLE_NAME exists."
  else
    log "Creating role $ROLE_NAME..."
    PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -c "CREATE ROLE $ROLE_NAME LOGIN;"
  fi

  log "Adding $PGUSER_RESTORE to role $ROLE_NAME..."
  PGPASSWORD=$PGPASSWORD_RESTORE psql -h $PGHOST_RESTORE -p $PGPORT_RESTORE -U $PGUSER_RESTORE -c "GRANT $ROLE_NAME TO $PGUSER_RESTORE;"

  # Check/handle existing database
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
  END_TIME=$(date +%s)
  log "Database $DB_NAME restored from $RESTORE_FILE_PATH in $(convertsecs $((END_TIME-START_TIME)))"
done

END_TIME_TOTAL_RESTORE=$(date +%s)
log "RESTORE COMPLETED in $(convertsecs $((END_TIME_TOTAL_RESTORE-START_TIME_TOTAL_RESTORE)))"

unset PGPASSWORD_RESTORE