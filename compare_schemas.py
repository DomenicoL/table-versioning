import sys
import subprocess
import re
import difflib
import os
import argparse

# --- DEBUGGING PRINT: This will show what arguments Python receives ---
print(f"Arguments received by script: {sys.argv}")
# --- End DEBUGGING PRINT ---

# Nomi dei file sorgente originali (senza prefisso)
ORIGINAL_COMMON_SQL = "common.sql"
ORIGINAL_VRSN_SQL = "vrsn.sql"

# Nomi dei file generati da prepare.sh (con prefisso LOCAL_INSTALL_)
LOCAL_INSTALL_COMMON_SQL_PREFIXED = "LOCAL_INSTALL_common.sql"
LOCAL_INSTALL_VRSN_SQL_PREFIXED = "LOCAL_INSTALL_vrsn.sql"

# Nomi dei file di changelog
GITHUB_CHANGELOG_FILE = "CHANGELOG.md"
LOCAL_CHANGELOG_FILE_PREFIXED = "LOCAL_INSTALL_CHANGELOG.md"


def parse_schema_dump(sql_dump_content):
    """
    Parses the content of an SQL dump, indexing objects by (Type, Schema, Name)
    and extracting the timestamp.
    """
    objects = {}
    timestamp = None

    # Extract the 'Started on' timestamp
    timestamp_match = re.search(r"-- Started on (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \w+)", sql_dump_content)
    if timestamp_match:
        timestamp = timestamp_match.group(1)

    # Regex to find TOC entry headers.
    toc_entry_pattern = re.compile(
        r'--\n'
        r'-- TOC entry \d+ \(class \d+ OID \d+\)\n'
        r'-- Name: (.+?); Type: (.+?); Schema: (.+?); Owner: .+?\n' # Captures Name, Type, Schema
        r'--\n', re.DOTALL
    )
    
    matches = list(toc_entry_pattern.finditer(sql_dump_content))

    for i, match in enumerate(matches):
        obj_name, obj_type, obj_schema = match.groups()

        content_start = match.end()
        content_end = len(sql_dump_content) 

        if i + 1 < len(matches):
            content_end = matches[i+1].start()
        
        raw_block_content = sql_dump_content[content_start:content_end].strip()
        
        clean_block = re.sub(r'^(SET\s[^\n]+\n)*', '', raw_block_content, flags=re.MULTILINE).strip()
        clean_block = re.sub(r'---\s*$', '', clean_block, flags=re.MULTILINE).strip()
        
        key = (obj_type, obj_schema, obj_name)
        objects[key] = clean_block

    return objects, timestamp

def compare_schemas(old_objects, new_objects):
    """Compares two dictionaries of schema objects and generates a detailed changelog."""
    changelog = []
    old_keys = set(old_objects.keys())
    new_keys = set(new_objects.keys())

    added_keys = sorted(list(new_keys - old_keys))
    for key in added_keys:
        changelog.append(f"✅ Added: {key[0]} '{key[2]}' (Schema: '{key[1]}')") # Type, Name, Schema

    removed_keys = sorted(list(old_keys - new_keys))
    for key in removed_keys:
        changelog.append(f"❌ Removed: {key[0]} '{key[2]}' (Schema: '{key[1]}')") # Type, Name, Schema

    modified_keys = sorted(list(old_keys.intersection(new_keys)))
    for key in modified_keys:
        if old_objects[key] != new_objects[key]:
            changelog.append(f"🔄 Modified: {key[0]} '{key[2]}' (Schema: '{key[1]}')") # Type, Name, Schema

    return "\n".join(changelog) if changelog else "No significant changes detected.\n"

def run_comparison(old_common_content, new_common_content, old_vrsn_content, new_vrsn_content):
    """Executes the comparison logic and prepares the changelog output."""
    old_common_objects, old_common_timestamp = parse_schema_dump(old_common_content)
    new_common_objects, new_common_timestamp = parse_schema_dump(new_common_content)
    common_changes = compare_schemas(old_common_objects, new_common_objects)

    old_vrsn_objects, old_vrsn_timestamp = parse_schema_dump(old_vrsn_content)
    new_vrsn_objects, new_vrsn_timestamp = parse_schema_dump(new_vrsn_content)
    vrsn_changes = compare_schemas(old_vrsn_objects, new_vrsn_objects)

    # Use the timestamp from the current dump if available, otherwise 'N/A'
    current_version_timestamp = new_common_timestamp or new_vrsn_timestamp or 'N/A'
    current_commit_hash = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()

    changelog_block = f"""
---
# Version {current_version_timestamp} ({current_commit_hash[:7]})

## common.sql
{common_changes}

## vrsn.sql
{vrsn_changes}
"""
    return changelog_block.strip(), common_changes, vrsn_changes

def main_logic():
    parser = argparse.ArgumentParser(description='Confronta le definizioni degli schemi e genera un changelog.')
    parser.add_argument('--mode', choices=['github-actions', 'local'], required=True, help='Modalità di esecuzione dello script.')
    parser.add_argument('--last-install-dir', help='Percorso della directory con gli ultimi script installati (solo in modalità local).')
    args = parser.parse_args()

    # Determine file names based on mode
    if args.mode == 'github-actions':
        current_common_file_to_read = ORIGINAL_COMMON_SQL
        current_vrsn_file_to_read = ORIGINAL_VRSN_SQL
        previous_common_file_name_for_git = ORIGINAL_COMMON_SQL
        previous_vrsn_file_name_for_git = ORIGINAL_VRSN_SQL
        output_changelog_file = GITHUB_CHANGELOG_FILE
    elif args.mode == 'local':
        current_common_file_to_read = LOCAL_INSTALL_COMMON_SQL_PREFIXED
        current_vrsn_file_to_read = LOCAL_INSTALL_VRSN_SQL_PREFIXED
        previous_common_file_name_for_local_dir = LOCAL_INSTALL_COMMON_SQL_PREFIXED
        previous_vrsn_file_name_for_local_dir = LOCAL_INSTALL_VRSN_SQL_PREFIXED
        output_changelog_file = LOCAL_CHANGELOG_FILE_PREFIXED


    # Read current content (from where the script is run)
    new_common_content = open(current_common_file_to_read, 'r').read()
    new_vrsn_content = open(current_vrsn_file_to_read, 'r').read()

    if args.mode == 'github-actions':
        try:
            previous_common_content = subprocess.run(['git', 'show', f'HEAD~1:{previous_common_file_name_for_git}'], capture_output=True, text=True, check=True).stdout
            previous_vrsn_content = subprocess.run(['git', 'show', f'HEAD~1:{previous_vrsn_file_name_for_git}'], capture_output=True, text=True, check=True).stdout
        except subprocess.CalledProcessError as e:
            print(f"Warning: Could not retrieve previous commit content (HEAD~1). Error: {e.stderr.strip()}. Assuming first run or file not present in previous commit.")
            previous_common_content = ""
            previous_vrsn_content = ""
        
        changelog_block, common_changes, vrsn_changes = run_comparison(previous_common_content, new_common_content, previous_vrsn_content, new_vrsn_content)

        if "No significant changes" in common_changes and "No significant changes" in vrsn_changes:
            print("No schema changes detected. Skipping changelog update.")
            sys.exit(0)
            
        old_changelog_content = ""
        if os.path.exists(output_changelog_file):
            with open(output_changelog_file, "r") as f:
                old_changelog_content = f.read()

        with open(output_changelog_file, "w") as f:
            f.write(changelog_block)
            if old_changelog_content:
                f.write("\n" + old_changelog_content)
    
    elif args.mode == 'local':
        if not args.last_install_dir:
            print("Error: --last-install-dir is required for 'local' mode.")
            sys.exit(1)

        last_common_path = os.path.join(args.last_install_dir, previous_common_file_name_for_local_dir)
        last_vrsn_path = os.path.join(args.last_install_dir, previous_vrsn_file_name_for_local_dir)
        
        try:
            with open(last_common_path, 'r') as f:
                previous_common_content = f.read()
            with open(last_vrsn_path, 'r') as f:
                previous_vrsn_content = f.read()
        except FileNotFoundError:
            print(f"Warning: Could not find files '{previous_common_file_name_for_local_dir}' and '{previous_vrsn_file_name_for_local_dir}' in '{args.last_install_dir}'. Assuming a fresh installation context for changelog.")
            previous_common_content = ""
            previous_vrsn_content = ""

        changelog_block, common_changes, vrsn_changes = run_comparison(previous_common_content, new_common_content, previous_vrsn_content, new_vrsn_content)
        
        if "No significant changes" in common_changes and "No significant changes" in vrsn_changes and (previous_common_content or previous_vrsn_content):
            print("No schema changes detected locally against LAST_INSTALL.")
            if os.path.exists(output_changelog_file):
                os.remove(output_changelog_file)
            sys.exit(0)

        with open(output_changelog_file, "w") as f:
            f.write(changelog_block)
        
        print(f"\n--- Changelog generato: {output_changelog_file} ---")
        print(changelog_block)

if __name__ == "__main__":
    main_logic()
