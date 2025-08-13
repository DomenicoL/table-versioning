import sys
import subprocess
import re
import difflib
import os
import argparse

# --- DEBUGGING PRINT: This will show what arguments Python receives ---
print(f"Arguments received by script: {sys.argv}")
# --- End DEBUGGING PRINT ---

# Nomi dei file con i placeholder
SOURCE_COMMON_SQL = "common.sql"
SOURCE_VRSN_SQL = "vrsn.sql"

def parse_schema_dump(sql_dump_content):
    """Parsa il contenuto di un dump SQL, indicizzando gli oggetti e estraendo il timestamp."""
    objects = {}
    timestamp = None

    timestamp_match = re.search(r"-- Started on (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \w+)", sql_dump_content)
    if timestamp_match:
        timestamp = timestamp_match.group(1)

    # Improved splitting logic for TOC entries
    # The regex now captures the entire header block including the "---" lines
    blocks = re.split(r'(--\n-- TOC entry \d+ \(.+\)\n-- Name: (.+); Type: (.+); Schema: (.+); Owner: .+\n--\n)', sql_dump_content)
    
    # blocks will now contain: [preamble, header_group1, content1, header_group2, content2, ...]
    # header_group is (full_header_block, oid, name, type, schema, owner)
    
    # Start from index 1 because index 0 is the preamble before the first TOC entry
    for i in range(1, len(blocks), 5): # Each TOC entry splits into 5 parts by the regex group
        if i + 4 >= len(blocks): # Ensure we don't go out of bounds
            continue # Malformed or last incomplete block

        full_header_block = blocks[i]
        
        # The split regex captures the groups from the header.
        # Let's re-extract the exact oid, name, obj_type from the full_header_block to be safe
        match_header = re.search(r'-- TOC entry (\d+) .* Name: (.+); Type: (.+);', full_header_block)
        if match_header:
            oid_actual, name_actual, obj_type_actual = match_header.groups()
            
            # The actual SQL content for this object is in blocks[i+4]
            clean_block = blocks[i+4].strip()
            
            # Remove any leading SET commands or blank lines that might follow the header and precede the actual object definition
            clean_block = re.sub(r'^(SET\s[^\n]+\n)*', '', clean_block, flags=re.MULTILINE).strip()
            
            key = (obj_type_actual, name_actual) # Use actual extracted name and type
            objects[key] = clean_block

    return objects, timestamp

def compare_schemas(old_objects, new_objects):
    """Confronta due dizionari di oggetti schema e genera un changelog dettagliato."""
    changelog = []
    old_keys = set(old_objects.keys())
    new_keys = set(new_objects.keys())

    added_keys = sorted(list(new_keys - old_keys))
    for key in added_keys:
        changelog.append(f"✅ Added: {key[0]} '{key[1]}'")

    removed_keys = sorted(list(old_keys - new_keys))
    for key in removed_keys:
        changelog.append(f"❌ Removed: {key[0]} '{key[1]}'")

    modified_keys = sorted(list(old_keys.intersection(new_keys)))
    for key in modified_keys:
        if old_objects[key] != new_objects[key]:
            changelog.append(f"🔄 Modified: {key[0]} '{key[1]}'")

    return "\n".join(changelog) if changelog else "No significant changes detected.\n"

def run_comparison(old_common_content, new_common_content, old_vrsn_content, new_vrsn_content):
    """Esegue la logica di confronto e prepara l'output del changelog."""
    old_common_objects, old_common_timestamp = parse_schema_dump(old_common_content)
    new_common_objects, new_common_timestamp = parse_schema_dump(new_common_content)
    common_changes = compare_schemas(old_common_objects, new_common_objects)

    old_vrsn_objects, old_vrsn_timestamp = parse_schema_dump(old_vrsn_content)
    new_vrsn_objects, new_vrsn_timestamp = parse_schema_dump(new_vrsn_content)
    vrsn_changes = compare_schemas(old_vrsn_objects, new_vrsn_objects)

    current_commit_hash = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()

    changelog_block = f"""
---
### Version {new_vrsn_timestamp or 'N/A'} ({current_commit_hash[:7]})

#### common.sql
{common_changes}

#### vrsn.sql
{vrsn_changes}
"""
    # Return common_changes and vrsn_changes to check if there were actual changes
    return changelog_block.strip(), common_changes, vrsn_changes

def main_logic(): # Renamed to avoid confusion with `main` entry point
    parser = argparse.ArgumentParser(description='Confronta le definizioni degli schemi e genera un changelog.')
    # CHANGED: 'mode' is now a required optional argument
    parser.add_argument('--mode', choices=['github-actions', 'local'], required=True, help='Execution mode of the script.')
    parser.add_argument('--last-install-dir', help='Path to the directory with the last installed scripts (only in local mode).')
    args = parser.parse_args()

    new_common_content = open(SOURCE_COMMON_SQL, 'r').read()
    new_vrsn_content = open(SOURCE_VRSN_SQL, 'r').read()

    if args.mode == 'github-actions':
        try:
            previous_common_content = subprocess.run(['git', 'show', f'HEAD~1:{SOURCE_COMMON_SQL}'], capture_output=True, text=True, check=True).stdout
            previous_vrsn_content = subprocess.run(['git', 'show', f'HEAD~1:{SOURCE_VRSN_SQL}'], capture_output=True, text=True, check=True).stdout
        except subprocess.CalledProcessError as e:
            # Handle cases where HEAD~1 might not exist (e.g., first commit) or file not found
            print(f"Warning: Could not retrieve previous commit content (HEAD~1). Error: {e.stderr.strip()}. Assuming first run or file not present in previous commit.")
            previous_common_content = ""
            previous_vrsn_content = ""
        
        changelog_block, common_changes, vrsn_changes = run_comparison(previous_common_content, new_common_content, previous_vrsn_content, new_vrsn_content)

        if "No significant changes" in common_changes and "No significant changes" in vrsn_changes:
            print("No schema changes detected. Skipping changelog update.")
            sys.exit(0) # Exit with 0 to indicate success, but no changes were made
            
        old_changelog_content = ""
        if os.path.exists("CHANGELOG.md"):
            with open("CHANGELOG.md", "r") as f:
                old_changelog_content = f.read()

        with open("CHANGELOG.md", "w") as f:
            f.write(changelog_block)
            if old_changelog_content:
                f.write("\n" + old_changelog_content)
    
    elif args.mode == 'local':
        if not args.last_install_dir:
            print("Error: --last-install-dir is required for 'local' mode.")
            sys.exit(1)

        last_common_path = os.path.join(args.last_install_dir, os.path.basename(SOURCE_COMMON_SQL))
        last_vrsn_path = os.path.join(args.last_install_dir, os.path.basename(SOURCE_VRSN_SQL))
        
        try:
            with open(last_common_path, 'r') as f:
                previous_common_content = f.read()
            with open(last_vrsn_path, 'r') as f:
                previous_vrsn_content = f.read()
        except FileNotFoundError:
            print(f"Warning: Could not find files in '{args.last_install_dir}'. Assuming a fresh installation context for changelog.")
            previous_common_content = ""
            previous_vrsn_content = ""

        changelog_block, common_changes, vrsn_changes = run_comparison(previous_common_content, new_common_content, previous_vrsn_content, new_vrsn_content)
        
        with open("CHANGELOG_generated.md", "w") as f:
            f.write(changelog_block)
        
        print("\n--- Changelog generated ---")
        print(changelog_block)

if __name__ == "__main__":
    main_logic() # Call the main logic function
