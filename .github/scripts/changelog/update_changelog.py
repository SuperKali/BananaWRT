#!/usr/bin/env python3
import os
import re
import sys
import time
from datetime import datetime, timedelta
from github import Github
import git
import emoji

RELEASE_DATE = os.environ.get('RELEASE_DATE', datetime.now().strftime('%Y-%m-%d'))
MAIN_REPO_PATH = os.getcwd()
PACKAGES_REPO_PATH = os.environ.get('PACKAGES_REPO_PATH')
DAYS_BACK = os.environ.get('DAYS_BACK')

if not PACKAGES_REPO_PATH:
    print("Error: PACKAGES_REPO_PATH not set")
    sys.exit(1)
CHANGELOG_PATH = os.path.join(MAIN_REPO_PATH, 'CHANGELOG.md')
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')

EMOJI_MAP = {
    'fix': '🐛',
    'bug': '🐛',
    'feature': '✨',
    'add': '➕',
    'update': '🔄',
    'upgrade': '🔼',
    'bump': '🔼',
    'improve': '🌟',
    'enhance': '🌟',
    'optimize': '⚡',
    'refactor': '♻️',
    'docs': '📝',
    'doc': '📝',
    'style': '🎨',
    'perf': '⚡',
    'test': '🧪',
    'build': '🏗️',
    'ci': '🔄',
    'chore': '🧹',
    'revert': '⏪',
    'security': '🔒',
    'remove': '🗑️',
    'config': '⚙️',
    'package': '📦',
    'ui': '💅',
    'misc': '🛠️',
    'fan': '🌬️',
    'temp': '🌡️',
    'warning': '⚠️',
    'translation': '🌐',
    'network': '🔌',
    'core': '🍌',
    'info': 'ℹ️',
    'utils': '🛠️',
    'cleanup': '🧹',
    'support': '📢',
    'align': '♻️'
}

CATEGORIES = {
    'additional_packages': {
        'name': '🧩 Additional Packages',
        'patterns': [
            r'banana-utils', r'luci-app-', r'linkup-optimization', r'modemband', 
            r'sms-tool', r'package', r'lib', r'-app-', r'-tool', r'opkg'
        ]
    },
    'bananawrt_core': {
        'name': '🍌 BananaWRT Core',
        'patterns': [
            r'workflow', r'github', r'action', r'script', r'dts', r'\.yml', r'\.yaml', 
            r'ci', r'cd', r'template', r'core', r'readme', r'documentation', r'changelog', 
            r'config', r'kernel', r'bug', r'fix', r'feat', r'feature'
        ]
    }
}

def get_last_changelog_date():
    if DAYS_BACK:
        try:
            days = int(DAYS_BACK)
            print(f"Using manual input: looking back {days} days")
            return datetime.now() - timedelta(days=days)
        except ValueError:
            print(f"Warning: Invalid DAYS_BACK value: {DAYS_BACK}. Using default method.")
    
    try:
        with open(CHANGELOG_PATH, 'r') as f:
            content = f.read()
        
        date_matches = re.findall(r'## \[(\d{4}-\d{2}-\d{2})\]', content)
        if date_matches:
            last_date_str = date_matches[0]
            return datetime.strptime(last_date_str, '%Y-%m-%d')
    except Exception as e:
        print(f"Error getting last changelog date: {e}")
    
    return datetime.now() - timedelta(days=30)

def get_emoji_for_commit(commit_msg):
    commit_msg_lower = commit_msg.lower()
    
    found_emojis = emoji.emoji_list(commit_msg)
    if found_emojis:
        return found_emojis[0]['emoji']
    
    for keyword, emoji_code in EMOJI_MAP.items():
        if keyword in commit_msg_lower:
            return emoji_code
    
    return '🛠️'

def categorize_commit(commit_msg, files_changed):
    commit_msg_lower = commit_msg.lower()
    
    for category, details in CATEGORIES.items():
        for pattern in details['patterns']:
            if re.search(pattern, commit_msg_lower, re.IGNORECASE):
                return category
        
        if files_changed:
            for file_path in files_changed:
                file_path_lower = file_path.lower()
                for pattern in details['patterns']:
                    if re.search(pattern, file_path_lower, re.IGNORECASE):
                        return category
    
    return 'additional_packages'

def format_commit_message(commit, author):
    message = commit.message.split('\n')[0].strip()
    
    package_match = re.search(r'`([^`]+)`', message)
    if not package_match:
        package_match = re.search(r'\b(luci-app-\w+|\w+-utils|modemband|linkup-optimization|sms-tool)\b', message, re.IGNORECASE)
    
    emoji_code = get_emoji_for_commit(message)
    
    found_emojis = emoji.emoji_list(message)
    if found_emojis and found_emojis[0]['match_start'] == 0:
        message = message[found_emojis[0]['match_end']:].strip()
    
    message = re.sub(r'^(package|luci-app-\w+|banana-utils|linkup-optimization|modemband):\s*', '', message, flags=re.IGNORECASE)
    
    if message and len(message) > 0:
        message = message[0].upper() + message[1:]
    
    if package_match:
        package_name = package_match.group(1)
        if '`' not in message:
            if package_name.lower() in message.lower():
                message = re.sub(
                    r'\b' + re.escape(package_name) + r'\b', 
                    f'`{package_name}`', 
                    message, 
                    flags=re.IGNORECASE
                )
            else:
                message = f'`{package_name}`: {message}'
    
    return f"{emoji_code} {message} by @{author}"

def get_commit_files(repo, commit_sha):
    try:
        commit = repo.commit(commit_sha)
        return [item.a_path for item in commit.diff(commit.parents[0])]
    except:
        return []

def get_recent_commits(repo_path, since_date=None):
    try:
        repo = git.Repo(repo_path)
        
        if since_date is None:
            since_date = get_last_changelog_date()
        
        since_date_str = since_date.strftime('%Y-%m-%d')
        print(f"Getting commits since {since_date_str} from {repo_path}")
        
        commits = []
        for commit in repo.iter_commits(since=since_date_str):
            commit_date = datetime.fromtimestamp(commit.committed_date)
            author = commit.author.name
            if author == "GitHub Actions":
                author = "SuperKali"
            
            files_changed = get_commit_files(repo, commit.hexsha)
            
            if len(commit.parents) > 1 or "Merge" in commit.message or "workflow" in commit.message.lower():
                continue
                
            if any(skip in commit.message.lower() for skip in ["typo", "readme", "whitespace", "spacing", "indent"]):
                continue
                
            commits.append({
                'sha': commit.hexsha,
                'message': commit.message,
                'author': author,
                'date': commit_date,
                'files': files_changed,
                'formatted': format_commit_message(commit, author),
                'category': categorize_commit(commit.message, files_changed)
            })
        
        return commits
    except Exception as e:
        print(f"Error getting commits from {repo_path}: {e}")
        return []

def update_release_date(content, release_date):
    date_obj = datetime.strptime(release_date, '%Y-%m-%d')
    formatted_date = date_obj.strftime('%B %d, %Y')
    
    date_pattern = r'📅 Release date: \*\*.*\*\*'
    new_date_line = f'📅 Release date: **{formatted_date}**'
    
    if re.search(date_pattern, content):
        return re.sub(date_pattern, new_date_line, content)
    else:
        lines = content.split('\n')
        if len(lines) > 1:
            lines[-1] = new_date_line
            lines.append('')
            return '\n'.join(lines)
        else:
            return content + f'\n\n{new_date_line}'

def get_commit_hash(commit_msg):
    """Extract a unique identifier from a commit message to avoid duplication"""
    msg_clean = re.sub(r'by @\w+$', '', commit_msg).strip()
    return hash(msg_clean)

def update_changelog():
    print(f"Updating changelog for release date: {RELEASE_DATE}")
    
    last_date = get_last_changelog_date()
    print(f"Found last changelog date: {last_date.strftime('%Y-%m-%d')}")
    
    if not os.path.isdir(PACKAGES_REPO_PATH) or not os.path.isdir(os.path.join(PACKAGES_REPO_PATH, '.git')):
        print(f"Warning: External repository not found at {PACKAGES_REPO_PATH}. Skipping external commits.")
        main_commits = get_recent_commits(MAIN_REPO_PATH, last_date)
        packages_commits = []
    else:
        main_commits = get_recent_commits(MAIN_REPO_PATH, last_date)
        packages_commits = get_recent_commits(PACKAGES_REPO_PATH, last_date)
    
    print(f"Found {len(main_commits)} commits in main repository")
    print(f"Found {len(packages_commits)} commits in packages repository")
    
    all_commits = main_commits + packages_commits
    
    if not all_commits:
        print("No new commits found since last changelog update. Exiting.")
        return False
    
    with open(CHANGELOG_PATH, 'r') as f:
        original_content = f.read()
    
    categorized_commits = {}
    for category in CATEGORIES:
        categorized_commits[category] = []
    
    for commit in all_commits:
        category = commit['category']
        categorized_commits[category].append(commit['formatted'])
    
    with open(CHANGELOG_PATH, 'r') as f:
        content = f.read()
    
    existing_commit_hashes = set()
    if f"## [{RELEASE_DATE}]" in content:
        print(f"Release date {RELEASE_DATE} already exists in changelog")
        
        section_pattern = r'## \[' + RELEASE_DATE + r'\](.*?)(?=## \[|$)'
        section_match = re.search(section_pattern, content, re.DOTALL)
        if section_match:
            section_content = section_match.group(1)
            commit_lines = re.findall(r'- (.*?)(?=\n- |\n\n|\n###|\Z)', section_content, re.DOTALL)
            for line in commit_lines:
                existing_commit_hashes.add(get_commit_hash(line.strip()))
        
        print(f"Found {len(existing_commit_hashes)} existing commit entries")
        
        new_content = []
        found_section = False
        in_target_section = False
        current_category = None
        
        for line in content.split('\n'):
            if f"## [{RELEASE_DATE}]" in line:
                new_content.append(line)
                in_target_section = True
                found_section = True
            elif in_target_section and line.startswith('## ['):
                added_commits = False
                for category, commits in categorized_commits.items():
                    if commits:
                        category_exists = False
                        category_line_idx = -1
                        
                        for i, l in enumerate(new_content):
                            if l == f"### {CATEGORIES[category]['name']}" and i > 0 and new_content[i-1].startswith('## [' + RELEASE_DATE):
                                category_exists = True
                                category_line_idx = i
                                break
                        
                        if category_exists:
                            insertion_index = category_line_idx + 1
                            while insertion_index < len(new_content) and not (new_content[insertion_index].startswith('###') or new_content[insertion_index].startswith('## [')):
                                insertion_index += 1
                                
                            for commit in commits:
                                commit_hash = get_commit_hash(commit)
                                if commit_hash not in existing_commit_hashes:
                                    new_content.insert(insertion_index, f"- {commit}")
                                    existing_commit_hashes.add(commit_hash)
                                    insertion_index += 1
                                    added_commits = True
                                    print(f"Added new commit: {commit[:50]}...")
                        else:
                            insertion_idx = len(new_content)
                            while insertion_idx > 0 and not new_content[insertion_idx-1].startswith('## ['):
                                insertion_idx -= 1
                            
                            if insertion_idx > 0:
                                new_content.insert(insertion_idx, '')
                                new_content.insert(insertion_idx + 1, f"### {CATEGORIES[category]['name']}")
                                new_content.insert(insertion_idx + 2, '')
                                
                                for commit in commits:
                                    commit_hash = get_commit_hash(commit)
                                    if commit_hash not in existing_commit_hashes:
                                        new_content.insert(insertion_idx + 3, f"- {commit}")
                                        existing_commit_hashes.add(commit_hash)
                                        added_commits = True
                                        print(f"Added new commit in new category: {commit[:50]}...")
                
                if not new_content[-1].strip() == '---':
                    new_content.append('')
                    new_content.append('---')
                
                in_target_section = False
                new_content.append(line)
                
                if not added_commits:
                    update_marker = f"<!-- Updated: {time.time()} -->"
                    new_content.append(update_marker)
                    print("No new commits to add, adding timestamp marker to force change")
            elif in_target_section and line.startswith('### '):
                current_category = None
                for cat, details in CATEGORIES.items():
                    if line == f"### {details['name']}":
                        current_category = cat
                        break
                new_content.append(line)
            elif in_target_section and line.strip() == '---':
                in_target_section = False
                new_content.append(line)
            else:
                new_content.append(line)
        
        if in_target_section:
            for category, commits in categorized_commits.items():
                if commits:
                    category_exists = False
                    for i, l in enumerate(new_content):
                        if l == f"### {CATEGORIES[category]['name']}":
                            category_exists = True
                            break
                    
                    if not category_exists:
                        new_content.append('')
                        new_content.append(f"### {CATEGORIES[category]['name']}")
                        new_content.append('')
                    
                    for commit in commits:
                        commit_hash = get_commit_hash(commit)
                        if commit_hash not in existing_commit_hashes:
                            new_content.append(f"- {commit}")
                            existing_commit_hashes.add(commit_hash)
            
            if not new_content[-1].strip() == '---':
                new_content.append('')
                new_content.append('---')
                new_content.append('')
        
        content = '\n'.join(new_content)
        
        if not found_section:
            print("Section not found despite matching pattern. Creating new section.")
            new_entry = [f"\n## [{RELEASE_DATE}]\n"]
            
            for category, commits in categorized_commits.items():
                if commits:
                    new_entry.append(f"### {CATEGORIES[category]['name']}\n")
                    for commit in commits:
                        new_entry.append(f"- {commit}")
                    new_entry.append("")
            
            new_entry.append("---\n")
            
            parts = content.split('---', 1)
            if len(parts) > 1:
                content = parts[0] + '---' + '\n' + '\n'.join(new_entry) + parts[1]
            else:
                title_end = content.find('\n\n')
                if title_end != -1:
                    content = content[:title_end+2] + '---\n\n' + '\n'.join(new_entry) + content[title_end+2:]
                else:
                    content = '\n'.join(new_entry) + content
    else:
        print(f"Creating new section for release date {RELEASE_DATE}")
        new_entry = [f"\n## [{RELEASE_DATE}]\n"]
        
        for category, commits in categorized_commits.items():
            if commits:
                new_entry.append(f"### {CATEGORIES[category]['name']}\n")
                for commit in commits:
                    new_entry.append(f"- {commit}")
                new_entry.append("")
        
        new_entry.append("---\n")
        
        parts = content.split('---', 1)
        if len(parts) > 1:
            content = parts[0] + '---' + '\n' + '\n'.join(new_entry) + parts[1]
        else:
            title_end = content.find('\n\n')
            if title_end != -1:
                content = content[:title_end+2] + '---\n\n' + '\n'.join(new_entry) + content[title_end+2:]
            else:
                content = '\n'.join(new_entry) + content
    
    content = update_release_date(content, RELEASE_DATE)
    
    content += f"\n<!-- Last updated: {datetime.now().isoformat()} -->\n"
    
    if content.strip() == original_content.strip():
        print("No changes detected in content. Adding timestamp marker.")
        content += f"\n<!-- Generated timestamp: {time.time()} -->\n"
    
    with open(CHANGELOG_PATH, 'w') as f:
        f.write(content)
    
    print("Changelog updated successfully!")
    return True

if __name__ == "__main__":
    update_changelog()