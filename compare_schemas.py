import subprocess
import re
import difflib
import os
import argparse

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

    blocks = re.split(r'(--\n-- TOC entry \d+ \(.+\)\n-- Name: (.+); Type: (.+); Schema: (.+); Owner: .+\n--\n)', sql_dump_content)
    
    # Questo è un approccio semplificato, la regex potrebbe necessitare di affinamento per blocchi complessi.
    for i in range(1, len(blocks), 5):
        try:
            block = blocks[i] + blocks[i+1] + blocks[i+2] + blocks[i+3] + blocks[i+4]
            match = re.search(r'-- TOC entry (\d+) .* Name: (.+); Type: (.+);', blocks[i])
            if match:
                oid, name, obj_type = match.groups()
                clean_block = re.sub(r'--\n-- TOC entry .+? --\n|SET .+\n|\n\n', '', block, flags=re.DOTALL).strip()
                key = (obj_type, name) 
                objects[key] = clean_block
        except IndexError:
            continue

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
    return changelog_block.strip(), common_changes, vrsn_changes

def main():
    parser = argparse.ArgumentParser(description='Confronta le definizioni degli schemi e genera un changelog.')
    parser.add_argument('mode', choices=['github-actions', 'local'], help='Modalità di esecuzione dello script.')
    parser.add_argument('--last-install-dir', help='Percorso della directory con gli ultimi script installati (solo in modalità local).')
    args = parser.parse_args()

    new_common_content = open(SOURCE_COMMON_SQL, 'r').read()
    new_vrsn_content = open(SOURCE_VRSN_SQL, 'r').read()

    if args.mode == 'github-actions':
        try:
            previous_common_content = subprocess.run(['git', 'show', f'HEAD~1:{SOURCE_COMMON_SQL}'], capture_output=True, text=True, check=True).stdout
            previous_vrsn_content = subprocess.run(['git', 'show', f'HEAD~1:{SOURCE_VRSN_SQL}'], capture_output=True, text=True, check=True).stdout
        except subprocess.CalledProcessError:
            previous_common_content = ""
            previous_vrsn_content = ""
        
        changelog_block, common_changes, vrsn_changes = run_comparison(previous_common_content, new_common_content, previous_vrsn_content, new_vrsn_content)

        if "No significant changes" in common_changes and "No significant changes" in vrsn_changes:
            print("No schema changes detected.")
            exit(0)
            
        old_changelog_content = ""
        if os.path.exists("CHANGELOG.md"):
            with open("CHANGELOG.md", "r") as f:
                old_changelog_content = f.read()

        with open("CHANGELOG.md", "w") as f:
            f.write(changelog_block)
            if old_changelog_content:
                f.write("\n" + old_changelog_content)
    
    elif args.mode == 'local':
        last_common_path = os.path.join(args.last_install_dir, os.path.basename(SOURCE_COMMON_SQL))
        last_vrsn_path = os.path.join(args.last_install_dir, os.path.basename(SOURCE_VRSN_SQL))
        
        try:
            with open(last_common_path, 'r') as f:
                previous_common_content = f.read()
            with open(last_vrsn_path, 'r') as f:
                previous_vrsn_content = f.read()
        except FileNotFoundError:
            print(f"Warning: Could not find files in '{args.last_install_dir}'. Assuming a fresh installation.")
            previous_common_content = ""
            previous_vrsn_content = ""

        changelog_block, common_changes, vrsn_changes = run_comparison(previous_common_content, new_common_content, previous_vrsn_content, new_vrsn_content)
        
        with open("CHANGELOG_generated.md", "w") as f:
            f.write(changelog_block)
        
        print("\n--- Changelog generated ---")
        print(changelog_block)

if __name__ == "__main__":
    main()
