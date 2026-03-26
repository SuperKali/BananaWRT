#!/usr/bin/env python3
import os
import re
import sys
from datetime import datetime, timedelta
from github import Github
import git
import emoji

RELEASE_DATE = os.environ.get('RELEASE_DATE', datetime.now().strftime('%Y-%m-%d'))
MAIN_REPO_PATH = os.getcwd()
DAYS_BACK = os.environ.get('DAYS_BACK')

# Support multiple package repos (comma-separated) or single repo
PACKAGES_REPO_PATHS_STR = os.environ.get('PACKAGES_REPO_PATHS', '')
PACKAGES_REPO_PATH = os.environ.get('PACKAGES_REPO_PATH', '')

if PACKAGES_REPO_PATHS_STR:
    PACKAGES_REPO_LIST = [p.strip() for p in PACKAGES_REPO_PATHS_STR.split(',') if p.strip()]
elif PACKAGES_REPO_PATH:
    PACKAGES_REPO_LIST = [PACKAGES_REPO_PATH]
else:
    print("Error: PACKAGES_REPO_PATHS or PACKAGES_REPO_PATH not set")
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
        'name': '🧩 Additional Packages'
    },
    'bananawrt_core': {
        'name': '🍌 BananaWRT Core'
    }
}

def extract_commit_signatures_from_changelog():
    signatures = set()
    try:
        if not os.path.exists(CHANGELOG_PATH):
            return signatures
        
        with open(CHANGELOG_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        
        commit_lines = re.findall(r'^- (.+?) by @(\w+)', content, re.MULTILINE)
        
        for commit_msg, author in commit_lines:
            normalized_msg = re.sub(r'[^\w\s`-]', '', commit_msg).strip().lower()
            normalized_msg = re.sub(r'\s+', ' ', normalized_msg)
            signature = f"{normalized_msg}|{author.lower()}"
            signatures.add(signature)
        
        print(f"Extracted {len(signatures)} commit signatures from existing changelog")
        return signatures
        
    except Exception as e:
        print(f"Warning: Error extracting commit signatures: {e}")
        return signatures

def create_commit_signature(commit, author):
    try:
        message = commit.message.split('\n')[0].strip()
        normalized_msg = re.sub(r'[^\w\s`-]', '', message).strip().lower()
        normalized_msg = re.sub(r'\s+', ' ', normalized_msg)
        safe_author = author if author and author != "GitHub Actions" else "SuperKali"
        return f"{normalized_msg}|{safe_author.lower()}"
    except Exception:
        return f"unknown|{author.lower()}"

def get_last_changelog_date():
    if DAYS_BACK:
        try:
            days = int(DAYS_BACK)
            print(f"Using manual input: looking back {days} days")
            return datetime.now() - timedelta(days=days)
        except ValueError:
            print(f"Warning: Invalid DAYS_BACK value: {DAYS_BACK}. Using default method.")
    
    try:
        with open(CHANGELOG_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        
        date_matches = re.findall(r'## \[(\d{4}-\d{2}-\d{2})\]', content)
        if date_matches:
            last_date_str = date_matches[0]
            print(f"Found last changelog date: {last_date_str}")
            return datetime.strptime(last_date_str, '%Y-%m-%d')
    except Exception as e:
        print(f"Error getting last changelog date: {e}")
    
    fallback_days = 7
    print(f"Using fallback: looking back {fallback_days} days")
    return datetime.now() - timedelta(days=fallback_days)

def get_emoji_for_commit(commit_msg):
    if not commit_msg:
        return '🛠️'
        
    commit_msg_lower = commit_msg.lower().strip()
    
    try:
        found_emojis = emoji.emoji_list(commit_msg)
        if found_emojis and found_emojis[0]['match_start'] == 0:
            return found_emojis[0]['emoji']
    except Exception:
        pass
    
    for keyword, emoji_code in EMOJI_MAP.items():
        if re.search(r'\b' + re.escape(keyword) + r'\b', commit_msg_lower):
            return emoji_code
    
    return '🛠️'

def categorize_commit(commit_msg, files_changed, repo_type=None):
    if repo_type == 'packages':
        return 'additional_packages'
    elif repo_type == 'main':
        return 'bananawrt_core'
    
    return 'additional_packages'

def format_commit_message(commit, author):
    try:
        if not commit or not commit.message:
            return f"🛠️ unknown commit by @{author}"
        
        message = commit.message.split('\n')[0].strip()
        if not message:
            return f"🛠️ empty commit message by @{author}"
        
        original_message = message
        
        try:
            found_emojis = emoji.emoji_list(message)
            if found_emojis and found_emojis[0]['match_start'] == 0:
                message = message[found_emojis[0]['match_end']:].strip()
        except Exception:
            pass
        
        prefixes_to_remove = [
            r'^(package|luci-app-\w+|banana-utils|linkup-optimization|modemband):\s*',
            r'^(fix|feat|feature|add|update|bump|improve):\s*',
            r'^[:\-\s]+'
        ]
        
        for prefix_pattern in prefixes_to_remove:
            message = re.sub(prefix_pattern, '', message, flags=re.IGNORECASE).strip()
        
        if not message:
            message = original_message
        
        message = message.lower()
        
        package_patterns = [
            r'`([^`]+)`',
            r'\b(luci-app-\w+|\w+-utils|modemband|linkup-optimization|sms-tool|banana-utils)\b'
        ]
        
        package_name = None
        for pattern in package_patterns:
            package_match = re.search(pattern, original_message, re.IGNORECASE)
            if package_match:
                package_name = package_match.group(1)
                break
        
        if package_name and '`' not in message:
            if package_name.lower() in message.lower():
                message = re.sub(
                    r'\b' + re.escape(package_name.lower()) + r'\b', 
                    f'`{package_name}`', 
                    message, 
                    flags=re.IGNORECASE
                )
            else:
                message = f'`{package_name}`: {message}'
        
        emoji_code = get_emoji_for_commit(original_message)
        safe_author = author if author and author != "GitHub Actions" else "SuperKali"
        
        return f"{emoji_code} {message} by @{safe_author}"
        
    except Exception as e:
        print(f"Error formatting commit message: {e}")
        return f"🛠️ {commit.message.split(chr(10))[0] if commit and commit.message else 'unknown'} by @{author}"

def get_commit_files(repo, commit_sha):
    try:
        if not repo or not commit_sha:
            return []
        commit = repo.commit(commit_sha)
        if not commit.parents:
            return []
        return [item.a_path for item in commit.diff(commit.parents[0]) if item.a_path]
    except Exception as e:
        print(f"Warning: Error getting files for commit {commit_sha}: {e}")
        return []

def should_skip_commit(commit_message):
    if not commit_message:
        return True
    
    skip_patterns = [
        r'\bmerge\b', r'\btypo\b', r'\breadme\b', r'\bwhitespace\b',
        r'\bspacing\b', r'\bindent\b', r'^merge\s+', r'^\s*$'
    ]
    
    commit_lower = commit_message.lower().strip()
    
    for pattern in skip_patterns:
        if re.search(pattern, commit_lower):
            return True
    
    return False

def get_recent_commits(repo_path, since_date, existing_signatures, repo_type='main'):
    try:
        if not os.path.isdir(repo_path) or not os.path.isdir(os.path.join(repo_path, '.git')):
            print(f"Warning: Invalid git repository at {repo_path}")
            return []
        
        repo = git.Repo(repo_path)
        since_date_str = since_date.strftime('%Y-%m-%d')
        print(f"Getting commits since {since_date_str} from {repo_path}")
        
        commits = []
        for commit in repo.iter_commits(since=since_date_str):
            try:
                if len(commit.parents) > 1:
                    continue
                
                if should_skip_commit(commit.message):
                    continue
                
                commit_date = datetime.fromtimestamp(commit.committed_date)
                author = commit.author.name if commit.author and commit.author.name else "Unknown"
                
                if author == "GitHub Actions":
                    author = "SuperKali"
                
                signature = create_commit_signature(commit, author)
                if signature in existing_signatures:
                    continue
                
                files_changed = get_commit_files(repo, commit.hexsha)
                formatted_message = format_commit_message(commit, author)
                category = categorize_commit(commit.message, files_changed, repo_type)
                
                commits.append({
                    'sha': commit.hexsha,
                    'message': commit.message,
                    'author': author,
                    'date': commit_date,
                    'files': files_changed,
                    'formatted': formatted_message,
                    'category': category,
                    'signature': signature,
                    'repo_type': repo_type
                })
                
            except Exception as e:
                print(f"Warning: Error processing commit {commit.hexsha}: {e}")
                continue
        
        print(f"Found {len(commits)} new commits")
        return commits
        
    except Exception as e:
        print(f"Error getting commits from {repo_path}: {e}")
        return []

def create_new_changelog_entry(categorized_commits, release_date):
    new_entry = [f"## [{release_date}]\n"]
    
    for category, commits in categorized_commits.items():
        if commits:
            new_entry.append(f"### {CATEGORIES[category]['name']}\n")
            for commit in commits:
                new_entry.append(f"- {commit}  ")
            new_entry.append("")
    
    new_entry.append("---\n")
    return '\n'.join(new_entry)

def update_release_date(content, release_date):
    try:
        date_obj = datetime.strptime(release_date, '%Y-%m-%d')
        formatted_date = date_obj.strftime('%B %d, %Y')
        
        date_pattern = r'📅 Release date: \*\*.*?\*\*'
        new_date_line = f'📅 Release date: **{formatted_date}**'
        
        if re.search(date_pattern, content):
            return re.sub(date_pattern, new_date_line, content)
        else:
            if not content.endswith('\n'):
                content += '\n'
            content += f'{new_date_line}\n'
            return content
            
    except Exception as e:
        print(f"Error updating release date: {e}")
        return content

def update_changelog():
    try:
        print(f"Updating changelog for release date: {RELEASE_DATE}")
        
        existing_signatures = extract_commit_signatures_from_changelog()
        last_date = get_last_changelog_date()
        
        main_commits = get_recent_commits(MAIN_REPO_PATH, last_date, existing_signatures, 'main')

        packages_commits = []
        for pkg_repo_path in PACKAGES_REPO_LIST:
            if os.path.isdir(pkg_repo_path) and os.path.isdir(os.path.join(pkg_repo_path, '.git')):
                repo_name = os.path.basename(pkg_repo_path.rstrip('/'))
                print(f"Scanning packages repo: {repo_name}")
                commits = get_recent_commits(pkg_repo_path, last_date, existing_signatures, 'packages')
                packages_commits.extend(commits)
                # Add signatures to avoid duplicates across branches
                for c in commits:
                    existing_signatures.add(c['signature'])
            else:
                print(f"Warning: Packages repository not found at {pkg_repo_path}")

        print(f"Found {len(main_commits)} commits in main repository")
        print(f"Found {len(packages_commits)} commits in packages repositories")
        
        all_commits = main_commits + packages_commits
        
        if not all_commits:
            print("No new commits found since last changelog update.")
            return
        
        categorized_commits = {}
        for category in CATEGORIES:
            categorized_commits[category] = []
        
        for commit in all_commits:
            category = commit['category']
            categorized_commits[category].append(commit['formatted'])
        
        try:
            with open(CHANGELOG_PATH, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            print(f"Error reading changelog: {e}")
            return
        
        release_section = f"## [{RELEASE_DATE}]"
        section_exists = release_section in content
        
        if section_exists:
            print(f"Release date {RELEASE_DATE} already exists - will merge new commits")
        else:
            print(f"Creating new release section for {RELEASE_DATE}")
        
        if section_exists:
            lines = content.split('\n')
            
            for category, commits in categorized_commits.items():
                if not commits:
                    continue
                
                category_header = f"### {CATEGORIES[category]['name']}"
                
                section_start = -1
                section_end = -1
                category_start = -1
                category_end = -1
                
                for i, line in enumerate(lines):
                    if line == release_section:
                        section_start = i
                    elif section_start != -1 and line.startswith('## [') and i > section_start:
                        section_end = i
                        break
                    elif section_start != -1 and line == category_header:
                        category_start = i
                    elif category_start != -1 and (line.startswith('### ') or line.startswith('## [') or line.strip() == '---'):
                        category_end = i
                        break
                
                if section_end == -1:
                    for i in range(len(lines) - 1, -1, -1):
                        if lines[i].strip() == '---' and i > section_start:
                            section_end = i
                            break
                
                if category_start == -1:
                    if section_end == -1:
                        section_end = len(lines)
                    
                    insert_pos = section_end
                    for i in range(section_start + 1, section_end):
                        if lines[i].strip() == '---':
                            insert_pos = i
                            break
                    
                    lines.insert(insert_pos, f"### {CATEGORIES[category]['name']}")
                    lines.insert(insert_pos + 1, "")
                    
                    for j, commit in enumerate(commits):
                        lines.insert(insert_pos + 2 + j, f"- {commit}  ")
                    
                    lines.insert(insert_pos + 2 + len(commits), "")
                else:
                    if category_end == -1:
                        category_end = section_end if section_end != -1 else len(lines)
                    
                    for commit in commits:
                        lines.insert(category_end, f"- {commit}  ")
                        category_end += 1
            
            content = '\n'.join(lines)
        else:
            new_entry = create_new_changelog_entry(categorized_commits, RELEASE_DATE)
            
            lines = content.split('\n')
            insert_index = -1
            
            for i, line in enumerate(lines):
                if line.strip() == '---' and i > 0:
                    insert_index = i + 1
                    break
            
            if insert_index == -1:
                for i, line in enumerate(lines):
                    if re.match(r'## \[\d{4}-\d{2}-\d{2}\]', line):
                        insert_index = i
                        break
            
            if insert_index == -1:
                content += f"\n{new_entry}"
            else:
                lines.insert(insert_index, new_entry)
                content = '\n'.join(lines)
        
        content = update_release_date(content, RELEASE_DATE)
        
        with open(CHANGELOG_PATH, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print("Changelog updated successfully!")
        print(f"Processed {len(all_commits)} new commits")
        
    except Exception as e:
        print(f"Error updating changelog: {e}")
        sys.exit(1)

if __name__ == "__main__":
    update_changelog()