# PostgreSQL Database Dump and Restore Script

This script is designed to facilitate the process of dumping and restoring PostgreSQL databases. It allows you to specify multiple databases to be dumped and restored in parallel. The script prompts for passwords and verifies the database connections before performing the operations.

## Prerequisites

Before running this script, ensure that the following requirements are met:

- The script is executed on a machine with access to both the source (dump) and target (restore) PostgreSQL servers.
- PostgreSQL client tools (`psql`, `pg_dump`, `pg_restore`) are installed on the machine.
- Proper access and credentials are available for both the dump and restore servers.

## Usage

1. Open a terminal.
2. Provide execute permissions to the script file using the following command:

   ```bash
   chmod +x pg_dump_pg_restore.bash
   ```

3. Run the script using the following command:

   ```bash
   bash ./pg_dump_pg_restore.sh
   ```

## Configuration

The script includes several variables that you can modify according to your setup. The configurable variables are explained below:

- **PostgreSQL Credentials**:
  - `PGHOST_DUMP`: Hostname or IP address of the source (dump) PostgreSQL server.
  - `PGPORT_DUMP`: Port number of the source PostgreSQL server.
  - `PGUSER_DUMP`: Username for the source PostgreSQL server.
  - `PGHOST_RESTORE`: Hostname or IP address of the target (restore) PostgreSQL server.
  - `PGPORT_RESTORE`: Port number of the target PostgreSQL server.
  - `PGUSER_RESTORE`: Username for the target PostgreSQL server.

- **Array of Databases to Dump**:
  - The `DATABASES` array contains the names of the databases that will be dumped and restored. You can add or remove databases from this list as needed.

- **Number of Jobs for Parallel Dump and Restore**:
  - The `JOBS` variable determines the number of parallel jobs that will be used for dumping and restoring databases. Please note that the parallel option (`-j`) is only applicable to the directory format of `pg_dump`. In this script, the custom format (`-Fc`) is used, which does not support parallel dumping. However, you can modify the script to use the directory format if parallel dump is required.

- **Dump Directory**:
  - The `DUMP_DIR` variable specifies the directory where the SQL dump files will be stored. By default, a timestamp-based directory will be created in the current working directory. You can change this directory to a different location if desired.

- **Log File**:
  - The `LOGFILE` variable determines the path and name of the log file. By default, the log file will be created in the dump directory with the name `pg_dump_restore.log`. You can modify this variable to specify a different log file location or name.

## Logging

The script provides logging functionality to record the progress and results of the dump and restore operations. The log file contains timestamps and informative messages for each step performed. The log file is appended with each run, preserving the history of previous executions.

## Disk Space Check

Before initiating the dump process, the script checks the available disk space on the machine. The `REQUIRED_DISK_SPACE` variable specifies the minimum required disk space in megabytes (MB). If the available disk space (`CURRENT_DISK_SPACE`) is less than the required amount, the script will display an error message and exit.

## Dumping Databases

The script performs the following steps for each database specified in the `DATABASES` array:

1. Creates a dump file for the database using the `pg_dump` command with the custom format (`-Fc`).
2. Stores the dump file in the designated `DUMP_DIR` directory with a filename corresponding