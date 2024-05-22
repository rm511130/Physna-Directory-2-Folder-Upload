#!/bin/bash

# Usage:  $ upload-folder.sh -t <tenant> --folder <existing folder-name> --source <source-directory>
#
# Copies all files from source-directory to <folder-name>  on  <tenant>.physna.com
# as long as they don't already exist as files in the target <folder-name>
#
# Performs $ pcli.exe -t <tenant> invalidate at the beginning of the process to guarantee connectivity

# Check if the required number of arguments are passed
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 -t <tenant> --folder <folder-name> --source <source-directory>"
    exit 1
fi

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--tenant) tenant="$2"; shift ;;
        --folder) folder_name="$2"; shift ;;
        --source) source_directory="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Invalidate cache on tenant
pcli.exe -t "$tenant" invalidate
return_code=$?

# Change to the source directory
cd "$source_directory" || { echo "Directory does not exist or cannot be accessed: $source_directory"; exit 1; }

# Check if the directory is empty
if [ -z "$(ls -A .)" ]; then
    echo "The directory is empty: $source_directory"
    exit 1
fi

# Get list of files already on the tenant in the folder
existing_files=$(pcli.exe -t "$tenant" models --folder "$folder_name" | jq -r '.[] | .name')
if [ $? -ne 0 ]; then
    echo "Failed to fetch existing files from $tenant in folder $folder_name"
    exit 1
fi

# Get a list of local files
local_files=$(find . -maxdepth 1 -type f -printf "%f\n")

# Compute delta list
delta_files=$(comm -23 <(echo "$local_files" | sort) <(echo "$existing_files" | sort))

# Prepare summary
start_time=$(date)
source_files_count=$(echo "$local_files" | wc -l)
initial_folder_count=$(echo "$existing_files" | wc -l)
delta_files_count=$(echo "$delta_files" | wc -l)
upload_errors=0
successful_uploads=0

# Upload files from delta list
IFS=$'\n'
for file in $delta_files; do
    attempts=0
    while [ $attempts -lt 3 ]; do
        pcli.exe -t "$tenant" upload --folder "$folder_name" --input "$file"
        if [ $? -eq 0 ]; then
            ((successful_uploads++))
            break
        else
		    echo "Having trouble loading: $file"
            ((attempts++))
        fi
    done
    if [ $attempts -eq 3 ]; then
        ((upload_errors++))
    fi
done
unset IFS

# Finish summary
end_time=$(date)
execution_time=$(( $(date +%s) - $(date -d "$start_time" +%s) ))
total_files_in_folder=$((initial_folder_count + successful_uploads))

echo "Start-time: $start_time"
echo "Source-folder: $source_directory"
echo "Source-files count: $source_files_count"
echo "Tenant: $tenant"
echo "Folder-name: $folder_name"
echo "Folder-name initial count: $initial_folder_count"
echo "Number of files to be skipped: $(($initial_folder_count - $delta_files_count))"
echo "Number of files to be loaded: $delta_files_count"
echo "Number of upload errors: $upload_errors"
echo "Number of successful uploads: $successful_uploads"
echo "Total number of files in $folder_name: $total_files_in_folder"
echo "End-Time: $end_time"
echo "Time to execute: $(($execution_time / 3600))hr $((($execution_time / 60) % 60))min $(($execution_time % 60))sec"
