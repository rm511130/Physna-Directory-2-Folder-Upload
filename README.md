# Physna-Directory-2-Folder-Upload

Shell-script to upload files from a local directory into an existing Physna Enterprise folder (skipping files that already exist in the target folder).

# Syntax

Usage:  `$ upload-folder.sh -t <tenant> --folder <existing folder-name> --source <source-directory>`

Copies all files from `source-directory` to `folder-name`  on  `tenant.physna.com` as long as they don't already exist as files in the target `folder-name`

Performs `$ pcli.exe -t <tenant> invalidate` at the beginning of the process to guarantee connectivity

Outputs logs to `stdout` and, if errors are encountered, tries 3 times to load the "problematic" file before moving on to the next file.
