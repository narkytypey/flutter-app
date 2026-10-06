#!/bin/bash
# usage: push.sh "message"   (serialised with flock; safe for parallel callers)
cd /home/user/flutter-app || exit 1
exec 9>/tmp/restyle-git.lock
flock 9
B=$(git rev-parse --abbrev-ref HEAD)
git add -A && git commit -qm "$1" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01QyqEG8RQbm9YYwPZyH8KTn" || true
for i in 1 2 3; do
  git pull -q --rebase origin "$B" && git push -q origin "$B" && break
  sleep $((i*2))
done
if [ "$B" = design-exploration-restyle ] || [ "$B" = restyle-implementation ]; then git push -q -f origin HEAD:second/gracious-cannon-1eynaf 2>/dev/null; fi
git log --oneline -1
