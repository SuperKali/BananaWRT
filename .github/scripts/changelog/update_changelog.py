#!/usr/bin/env python3
import os
import re
import sys
import json
import hashlib
from datetime import datetime, timedelta, timezone
from github import Github
import git
import emoji
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

RELEASE_DATE = os.environ.get('RELEASE_DATE', datetime.now().strftime('%Y-%m-%d'))
MAIN_REPO_PATH = os.getcwd()
PACKAGES_REPO_PATH = os.environ.get('PACKAGES_REPO_PATH')
DAYS_BACK = os.environ.get('DAYS_BACK')
CHANGELOG_PATH = os.path.join(MAIN_REPO_PATH, 'CHANGELOG.md')
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')

FILTER_CONFIG = {
    "exclude_merge_commits": True,
    "exclude_patterns": [
        r'^typo:\s*fix',
        r'^docs:\s*update readme only',
        r'^style:\s*whitespace|spacing|indent'
    ],
    "include_workflow_commits": True
}

if not PACKAGES_REPO_PATH:
    logger.error("Error: PACKAGES_REPO_PATH not set")
    sys.exit(1)

EMOJI_MAP = {
    'fix': '🐛',
    'bug': '🐛',
    'hotfix': '🚑',
    'security': '🔒',
    'breaking': '💥',
    'feature': '✨',
    'feat': '✨',
    'add': '➕',
    'new': '🆕',
    'improve': '🌟',
    'enhance': '🌟',
    'optimize': '⚡',
    'perf': '⚡',
    'refactor': '♻️',
    'update': '🔄',
    'upgrade': '🔼',
    'bump': '🔼',
    'deps': '📦',
    'docs': '📝',
    'doc': '📝',
    'test': '🧪',
    'build': '🏗️',
    'ci': '🔄',
    'workflow': '🔄',
    'style': '🎨',
    'chore': '🧹',
    'cleanup': '🧹',
    'revert': '⏪',
    'remove': '🗑️',
    'config': '⚙️',
    'ui': '💅',
    'translation': '🌐',
    'i18n': '🌐',
    'network': '🔌',
    'core': '🍌',
    'package': '📦',
    'misc': '🛠️'
}

CATEGORIES = {
    'security_critical': {
        'name': '🔒 Security & Critical Fixes',
        'priority': 1,
        'patterns': [
            r'security|cve|vulnerability|exploit|auth|crypto|ssl|tls|certificate',
            r'critical|emergency|hotfix|urgent'
        ],
        'file_patterns': [
            r'security/', r'auth/', r'crypto/'
        ]
    },
    'features': {
        'name': '✨ New Features',
        'priority': 2,
        'patterns': [
            r'^feat:|^feature:|add.*feature|new.*feature|implement',
            r'introduce|create.*new'
        ],
        'file_patterns': []
    },
    'improvements': {
        'name': '🌟 Improvements & Enhancements',
        'priority': 3,
        'patterns': [
            r'improve|enhance|optimize|refactor|update.*logic|better',
            r'performance|speed|faster'
        ],
        'file_patterns': []
    },
    'bugfixes': {
        'name': '🐛 Bug Fixes',
        'priority': 4,
        'patterns': [
            r'fix:|bug:|resolve|correct|repair|patch',
            r'issue.*#\d+|fixes.*#\d+'
        ],
        'file_patterns': []
    },
    'bananawrt_core': {
        'name': '🍌 BananaWRT Core',
        'priority': 5,
        'patterns': [
            r'kernel|dts|openwrt|firmware|bootloader|uboot'
        ],
        'file_patterns': [
            r'target/', r'kernel/', r'\.dts', r'\.dtsi', r'config/Config-kernel'
        ]
    },
    'packages': {
        'name': '📦 Packages & Applications',
        'priority': 6,
        'patterns': [
            r'luci-app-|package:|^(\w+):\s*(add|update|fix|bump)',
            r'banana-utils|linkup-optimization|modemband|sms-tool'
        ],
        'file_patterns': [
            r'package/', r'feeds/', r'luci/'
        ]
    },
    'build_ci': {
        'name': '🔄 Build System & CI',
        'priority': 7,
        'patterns': [
            r'workflow|github.*action|ci:|cd:|build:|cmake|makefile'
        ],
        'file_patterns': [
            r'\.github/', r'\.yml$', r'\.yaml$', r'Makefile', r'CMakeLists\.txt'
        ]
    },
    'documentation': {
        'name': '📝 Documentation',
        'priority': 8,
        'patterns': [
            r'^docs:|documentation|readme|changelog|wiki'
        ],
        'file_patterns': [
            r'README', r'CHANGELOG', r'\.md$', r'docs/'
        ]
    },
    'other': {
        'name': '🛠️ Other Changes',
        'priority': 99,
        'patterns': [],
        'file_patterns': []
    }
}

def load_config():
    config_path = os.path.join(MAIN_REPO_PATH, '.changelog-config.json')
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
                FILTER_CONFIG.update(config.get('filters', {}))
                logger.info(f"Loaded configuration from {config_path}")
        except Exception as e:
            logger.warning(f"Failed to load config: {e}")

def get_last_changelog_date():
    if DAYS_BACK:
        try:
            days = int(DAYS_BACK)
            logger.info(f"Using manual input: looking back {days} days")
            return datetime.now(timezone.utc) - timedelta(days=days)
        except ValueError:
            logger.warning(f"Invalid DAYS_BACK value: {DAYS_BACK}. Using default method.")
    
    try:
        with open(CHANGELOG_PATH, 'r') as f:
            content = f.read()
        
        date_matches = re.findall(r'## \[(\d{4}-\d{2}-\d{2})\]', content)
        if date_matches:
            last_date_str = date_matches[0]
            last_date = datetime.strptime(last_date_str, '%Y-%m-%d').replace(tzinfo=timezone.utc)
            logger.info(f"Found last changelog date: {last_date_str}")
            return last_date
    except Exception as e:
        logger.error(f"Error getting last changelog date: {e}")
    
    default_date = datetime.now(timezone.utc) - timedelta(days=30)
    logger.info(f"No previous changelog found, using default: {default_date.strftime('%Y-%m-%d')}")
    return default_date

def should_skip_commit(commit):
    message_lower = commit.message.lower()
    
    if FILTER_CONFIG.get('exclude_merge_commits', True):
        if len(commit.parents) > 1:
            logger.debug(f"Skipping merge commit: {commit.hexsha[:8]}")
            return True
    
    for pattern in FILTER_CONFIG.get('exclude_patterns', []):
        if re.search(pattern, commit.message, re.IGNORECASE):
            logger.debug(f"Skipping commit matching exclude pattern: {commit.hexsha[:8]}")
            return True
    
    if not FILTER_CONFIG.get('include_workflow_commits', True):
        if 'workflow' in message_lower:
            return True
    
    return False

def get_emoji_for_commit(commit_msg):
    found_emojis = emoji.emoji_list(commit_msg)
    if found_emojis and found_emojis[0]['match_start'] == 0:
        return found_emojis[0]['emoji']
    
    commit_msg_lower = commit_msg.lower()
    
    for keyword, emoji_code in EMOJI_MAP.items():
        if re.search(r'\b' + keyword + r'\b', commit_msg_lower):
            return emoji_code
    
    return '🛠️'

def extract_package_name(message):
    patterns = [
        r'`([^`]+)`',
        r'^(\w+(?:-\w+)*):',
        r'\b(luci-app-\w+)\b',
        r'\b(banana-utils|linkup-optimization|modemband|sms-tool)\b'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, message, re.IGNORECASE)
        if match:
            return match.group(1)
    
    return None

def format_commit_message(commit, author):
    message = commit.message.split('\n')[0].strip()
    emoji_code = get_emoji_for_commit(message)
    
    found_emojis = emoji.emoji_list(message)
    if found_emojis and found_emojis[0]['match_start'] == 0:
        message = message[found_emojis[0]['match_end']:].strip()
    
    package_name = extract_package_name(message)
    
    if message and not message[0].isupper() and not re.match(r'^[a-z]+:', message):
        message = message[0].upper() + message[1:]
    
    if package_name and '`' not in message:
        message = re.sub(
            r'\b' + re.escape(package_name) + r'\b',
            f'`{package_name}`',
            message,
            count=1,
            flags=re.IGNORECASE
        )
    
    issue_match = re.search(r'(?:fixes?|closes?|resolves?)\s*#(\d+)', message, re.IGNORECASE)
    if issue_match:
        issue_num = issue_match.group(1)
        if f'(#{issue_num})' not in message:
            message += f' (#{issue_num})'
    
    return f"{emoji_code} {message} by @{author}"

def get_commit_files(repo, commit):
    try:
        if not commit.parents:
            return [item.a_path for item in commit.diff(None)]
        else:
            return [item.a_path for item in commit.diff(commit.parents[0])]
    except Exception as e:
        logger.warning(f"Error getting files for commit {commit.hexsha[:8]}: {e}")
        return []

def categorize_commit(commit_msg, files_changed):
    commit_msg_lower = commit_msg.lower()
    category_scores = {}
    
    for category, details in CATEGORIES.items():
        score = 0
        
        for pattern in details.get('patterns', []):
            if re.search(pattern, commit_msg_lower, re.IGNORECASE):
                score += 2
        
        for file_path in files_changed:
            for pattern in details.get('file_patterns', []):
                if re.search(pattern, file_path, re.IGNORECASE):
                    score += 1
        
        if score > 0:
            category_scores[category] = score
    
    if category_scores:
        best_category = max(category_scores, key=category_scores.get)
        if category_scores[best_category] < 2 and 'other' in CATEGORIES:
            return 'other'
        return best_category
    
    return 'other'

def get_commit_hash(commit):
    unique_string = f"{commit['sha']}:{commit['author']}:{commit['date']}"
    return hashlib.md5(unique_string.encode()).hexdigest()

def get_recent_commits(repo_path, since_date):
    try:
        repo = git.Repo(repo_path)
        repo_name = os.path.basename(repo_path)
        
        logger.info(f"Getting commits from {repo_name} since {since_date.strftime('%Y-%m-%d')}")
        
        commits = []
        seen_hashes = set()
        commit_count = 0
        
        for commit in repo.iter_commits(all=True):
            commit_date = datetime.fromtimestamp(commit.committed_date, tz=timezone.utc)
            
            if commit_date <= since_date:
                break
            
            commit_count += 1
            
            if should_skip_commit(commit):
                continue
            
            author = commit.author.name
            if author == "GitHub Actions":
                if commit.committer.name != "GitHub Actions":
                    author = commit.committer.name
                else:
                    author = "SuperKali"
            
            files_changed = get_commit_files(repo, commit)
            
            commit_data = {
                'sha': commit.hexsha,
                'message': commit.message,
                'author': author,
                'date': commit_date,
                'files': files_changed,
                'formatted': format_commit_message(commit, author),
                'category': categorize_commit(commit.message, files_changed),
                'repo': repo_name
            }
            
            commit_hash = get_commit_hash(commit_data)
            if commit_hash not in seen_hashes:
                seen_hashes.add(commit_hash)
                commits.append(commit_data)
        
        logger.info(f"Processed {commit_count} commits, kept {len(commits)} from {repo_name}")
        return commits
        
    except Exception as e:
        logger.error(f"Error getting commits from {repo_path}: {e}")
        return []

def sort_commits(commits):
    return sorted(commits, key=lambda x: x['date'], reverse=True)

def generate_changelog_entry(categorized_commits, release_date):
    lines = [f"\n## [{release_date}]\n"]
    
    sorted_categories = sorted(
        CATEGORIES.items(),
        key=lambda x: x[1].get('priority', 99)
    )
    
    has_content = False
    for category_key, category_info in sorted_categories:
        commits = categorized_commits.get(category_key, [])
        if commits:
            has_content = True
            lines.append(f"### {category_info['name']}\n")
            
            for commit in commits:
                lines.append(f"- {commit}")
            lines.append("")
    
    if not has_content:
        logger.warning("No commits to add to changelog")
        return None
    
    if os.environ.get('CHANGELOG_STATS', 'false').lower() == 'true':
        total_commits = sum(len(commits) for commits in categorized_commits.values())
        lines.append(f"\n**Total changes:** {total_commits} commits\n")
    
    lines.append("---\n")
    return lines

def update_release_date(content, release_date):
    date_obj = datetime.strptime(release_date, '%Y-%m-%d')
    formatted_date = date_obj.strftime('%B %d, %Y')
    
    date_pattern = r'📅 Release date: \*\*.*?\*\*'
    new_date_line = f'📅 Release date: **{formatted_date}**'
    
    if re.search(date_pattern, content):
        return re.sub(date_pattern, new_date_line, content)
    else:
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if line.strip() == '' and i > 0:
                lines.insert(i, new_date_line)
                break
        else:
            lines.append(new_date_line)
        return '\n'.join(lines)

def update_changelog():
    logger.info(f"Updating changelog for release date: {RELEASE_DATE}")
    
    load_config()
    
    last_date = get_last_changelog_date()
    
    all_commits = []
    
    main_commits = get_recent_commits(MAIN_REPO_PATH, last_date)
    all_commits.extend(main_commits)
    
    if os.path.isdir(PACKAGES_REPO_PATH) and os.path.isdir(os.path.join(PACKAGES_REPO_PATH, '.git')):
        packages_commits = get_recent_commits(PACKAGES_REPO_PATH, last_date)
        all_commits.extend(packages_commits)
    else:
        logger.warning(f"External repository not found at {PACKAGES_REPO_PATH}")
    
    if not all_commits:
        logger.info("No new commits found since last changelog update.")
        return
    
    all_commits = sort_commits(all_commits)
    
    categorized_commits = {}
    for commit in all_commits:
        category = commit['category']
        if category not in categorized_commits:
            categorized_commits[category] = []
        categorized_commits[category].append(commit['formatted'])
    
    try:
        with open(CHANGELOG_PATH, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        logger.error(f"Changelog file not found: {CHANGELOG_PATH}")
        content = "# Changelog\n\n"
    
    if f"## [{RELEASE_DATE}]" in content:
        logger.info(f"Release date {RELEASE_DATE} already exists in changelog")
        return
    else:
        logger.info(f"Creating new entry for {RELEASE_DATE}")
        new_entry = generate_changelog_entry(categorized_commits, RELEASE_DATE)
        
        if new_entry:
            if '---' in content:
                parts = content.split('---', 1)
                content = parts[0] + '---\n' + ''.join(new_entry) + parts[1]
            else:
                title_end = content.find('\n\n')
                if title_end != -1:
                    content = content[:title_end+2] + '---\n' + ''.join(new_entry) + content[title_end+2:]
                else:
                    content += '\n---\n' + ''.join(new_entry)
    
    content = update_release_date(content, RELEASE_DATE)
    
    with open(CHANGELOG_PATH, 'w') as f:
        f.write(content)
    
    logger.info("Changelog updated successfully!")
    
    total_commits = sum(len(commits) for commits in categorized_commits.values())
    logger.info(f"Summary: Added {total_commits} commits across {len(categorized_commits)} categories")
    for category, commits in categorized_commits.items():
        logger.info(f"  - {CATEGORIES[category]['name']}: {len(commits)} commits")

if __name__ == "__main__":
    try:
        update_changelog()
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)