# 🚀 Build Cache System

This document explains the multi-layer caching system implemented to accelerate OpenWRT/ImmortalWRT builds.

## Overview

Building OpenWRT firmware from scratch typically takes **60-90 minutes**. With our caching system, subsequent builds can complete in **20-30 minutes** when cache hits occur.

**Cache is enabled for:** Nightly builds only (weekly schedule)
**Cache is disabled for:** Stable builds (monthly, often with version upgrades)

## Cache Layers

### 1. 📦 Downloads Cache (`dl/`)

**What it caches:** Source tarballs for all packages (kernel, packages, toolchain sources)

**Cache key strategy:**
- Primary: `dl-{branch}-{feeds_hash}-{config_hash}`
- Fallback 1: `dl-{branch}-{feeds_hash}-`
- Fallback 2: `dl-{branch}-`
- Fallback 3: `dl-`

**Time saved:** ~5-10 minutes per build

**When it invalidates:**
- Package list changes in `.config`
- Feeds configuration changes
- Branch upgrade

### 2. 🔧 Toolchain Cache

**What it caches:** Compiled toolchain (GCC, binutils, glibc/musl, etc.)

**Cached directories:**
- `staging_dir/toolchain-*`
- `build_dir/toolchain-*`

**Cache key strategy:**
- Primary: `toolchain-{branch}-{target_hash}`
- Fallback: `toolchain-{branch}-`

**Time saved:** ~15-30 minutes per build

**When it invalidates:**
- Target architecture changes
- Kernel version changes
- Branch upgrade

### 3. 📚 Feeds Cache

**What it caches:** Downloaded and indexed package feeds

**Cached directories:**
- `feeds/`
- `package/feeds/`

**Cache key strategy:**
- Primary: `feeds-{branch}-{feeds_conf_hash}-{run_number}`
- Fallback 1: `feeds-{branch}-{feeds_conf_hash}-`
- Fallback 2: `feeds-{branch}-`

**Time saved:** ~2-5 minutes per build

**When it invalidates:**
- Feeds configuration changes
- New build run (to get latest updates)

## Cache Statistics

Each build displays cache hit/miss statistics in the GitHub Actions summary:

```
📊 Cache Status

| Cache Layer      | Status   | Key                          |
|------------------|----------|------------------------------|
| Downloads (dl/)  | ✅ Hit   | dl-24.10.4-a1b2c3d4-e5f6... |
| Toolchain        | ✅ Hit   | toolchain-24.10.4-12345678  |

⚡ Downloads cache hit! Skipping package downloads (~5-10 min saved)
⚡ Toolchain cache hit! Skipping toolchain compilation (~15-30 min saved)
```

## Why Cache Only Nightly Builds?

**Nightly builds** benefit most from caching because:
- Run weekly (every Sunday) - cache stays fresh
- Usually same version between builds
- High cache hit rate (70-90%)
- Time savings: 30-60 min per build

**Stable builds** have cache disabled because:
- Run monthly (1st of each month)
- Often accompanied by version upgrades (24.10.4 → 24.10.5)
- Cache would mostly miss on version changes
- Simpler workflow, no cache management overhead

## Expected Performance (Nightly Builds)

| Scenario | Cache Status | Build Time | Time Saved |
|----------|--------------|------------|------------|
| First nightly build | All miss | 60-90 min | 0 min |
| Second nightly (same week) | All hit | 20-30 min | 30-60 min |
| Nightly after config change | Toolchain hit, DL partial | 30-45 min | 15-45 min |
| Nightly after version upgrade | All miss | 60-90 min | 0 min |

## Cache Limits

GitHub Actions cache has the following limits:
- **Max size per cache entry:** 10 GB
- **Total cache size per repo:** 10 GB (older caches auto-deleted)
- **Cache retention:** 7 days of inactivity

Our typical cache sizes:
- Downloads: 1-3 GB
- Toolchain: 500 MB - 1.5 GB
- Feeds: 100-300 MB
- **Total:** ~2-5 GB (well within limits)

## Cache Management

### Forcing Cache Rebuild

To force a cache rebuild (e.g., after suspected corruption):

1. Go to GitHub repository settings
2. Navigate to Actions → Caches
3. Delete specific cache entries
4. Re-run the workflow

### Monitoring Cache Usage

View cache usage in:
- GitHub repository → Actions → Caches
- Workflow run summary (Cache Statistics section)

## Optimization Tips

### For Self-Hosted Runners

If using self-hosted runners, consider:

1. **Persistent workspace:** Keep `dl/` and `staging_dir/` between runs
2. **Local cache:** Use runner's disk instead of GitHub cache
3. **ccache:** Enable ccache for even faster compilation

Example `.github/workflows/build-reusable.yml` modification:

```yaml
- name: Setup ccache
  run: |
    sudo apt-get install -y ccache
    echo "export USE_CCACHE=1" >> ~/.bashrc
    ccache -M 10G
```

### For Large Projects

If your firmware includes many custom packages:

1. Consider caching `build_dir/target-*` (package builds)
2. Be mindful of 10GB cache limit
3. Use cache cleanup scripts

## Troubleshooting

### Cache Not Restoring

**Symptoms:** Cache shows as "miss" even though it should exist

**Possible causes:**
1. Cache key changed (config/feeds modified)
2. Cache expired (>7 days old)
3. Cache evicted (total size exceeded 10GB)

**Solution:**
- Check cache keys in workflow logs
- Verify no unintended config changes
- Run build to recreate cache

### Build Fails with Cached Toolchain

**Symptoms:** Build fails with strange compilation errors after cache restore

**Possible cause:** Toolchain cache corrupted or incompatible

**Solution:**
```bash
# In workflow, add cache validation:
- name: Validate Toolchain Cache
  run: |
    if [ -d "staging_dir/toolchain-*" ]; then
      # Test toolchain
      staging_dir/toolchain-*/bin/*-gcc --version || rm -rf staging_dir/toolchain-*
    fi
```

### Slow Download Despite Cache

**Symptoms:** `make download` still takes long time with cache hit

**Possible cause:** Partial cache or corrupted downloads

**Solution:**
```bash
# The workflow already includes this check:
find dl -size -1024c -exec rm -f {} \;
```

## Contributing

When modifying the cache system:

1. Test with both cache hit and miss scenarios
2. Monitor cache sizes (stay under 10GB total)
3. Update cache keys if dependencies change
4. Document changes in this file

## References

- [GitHub Actions Cache Documentation](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [OpenWRT Build System](https://openwrt.org/docs/guide-developer/toolchain/use-buildsystem)
- [ImmortalWRT Documentation](https://github.com/immortalwrt/immortalwrt)
