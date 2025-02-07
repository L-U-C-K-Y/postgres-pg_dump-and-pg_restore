#!/bin/bash

# PostgreSQL credentials
PGHOST_DUMP=dump-host.com
PGPORT_DUMP=5432
PGUSER_DUMP=postgres

# Array of databases to dump
DATABASES=(
  db1
  db2
  db3
)

# Create a timestamp tag
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
DUMP_DIR="./${TIMESTAMP}/"
mkdir -p $DUMP_DIR
LOGFILE="${DUMP_DIR}pg_dump.log"

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

# Check disk space
REQUIRED_DISK_SPACE=2048
CURRENT_DISK_SPACE=$(df / | tail -1 | awk '{print $4}')

if (( CURRENT_DISK_SPACE < REQUIRED_DISK_SPACE )); then
  log "Not enough disk space. Required: ${REQUIRED_DISK_SPACE}MB, Available: ${CURRENT_DISK_SPACE}MB"
  exit 1
fi

# Print connection info
log "Dump Connection:"
log "Host: $PGHOST_DUMP"
log "Port: $PGPORT_DUMP"
log "User: $PGUSER_DUMP"

# Get password
printf "Please enter the PostgreSQL password for dump: "
read -s PGPASSWORD_DUMP
export PGPASSWORD_DUMP
echo

# Test connection
PGPASSWORD=$PGPASSWORD_DUMP psql -h $PGHOST_DUMP -p $PGPORT_DUMP -U $PGUSER_DUMP -d postgres -c '\q' || exit 1
log "Dump connection successful."

log "STARTING DUMP"
START_TIME_TOTAL_DUMP=$(date +%s)

# Create dumps
for DB_NAME in "${DATABASES[@]}"
do
  DUMP_FILE="${DB_NAME}.dump"
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

unset PGPASSWORD_DUMP