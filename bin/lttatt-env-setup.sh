#!/usr/bin/env bash
set -euo pipefail

npmrc_auth_lines="$(mktemp)"
trap 'rm -f "$npmrc_auth_lines"' EXIT
if [ -f ~/.npmrc ]; then
  grep '^//' ~/.npmrc > "$npmrc_auth_lines" || true
fi

cat > ~/.npmrc << EOF
registry=https://registry.npmmirror.com/
electron_mirror=https://npmmirror.com/mirrors/electron/
EOF
cat "$npmrc_auth_lines" >> ~/.npmrc

cat > ~/.inputrc << EOF
set bell-style none
set show-all-if-ambiguous on
set completion-ignore-case on
EOF

mkdir -p ~/bin
cat > ~/.bashrc << EOF
export PATH="\$PATH:~/bin:~/Workspaces/VsCode/lttatt-skill/bin:/c/Program Files/GitHub CLI:/c/Program Files/Docker/Docker/resources/bin"

if [ -f "\$HOME/.local/bin/env" ]; then
  . "\$HOME/.local/bin/env"
fi
EOF

# cat ~/.bashrc
# export PATH="/c/Users/78157/bin:/mingw64/bin:/usr/local/bin:/usr/bin:/bin:/mingw64/bin:/usr/bin:/c/Users/78157/bin:/c/Program Files/Common Files/Oracle/Java/javapath:/c/windows/system32:/c/windows:/c/windows/System32/Wbem:/c/windows/System32/WindowsPowerShell/v1.0:/c/windows/System32/OpenSSH:/c/Program Files/dotnet:/cmd:/c/Program Files/Docker/Docker/resources/bin:/c/Program Files (x86)/NetSarang/Xshell 8:/c/Program Files (x86)/NetSarang/Xftp 8:/c/Program Files/PowerShell/7:/c/Program Files/GitHub CLI:/c/Users/78157/AppData/Local/nvm:/c/nvm4w/nodejs:/c/Users/78157/tools/apache-maven-3.9.14/bin:/c/ProgramData/chocolatey/bin:/c/Users/78157/AppData/Local/Programs/Python/Launcher:/c/Users/78157/.local/bin:/c/Users/78157/AppData/Local/Microsoft/WindowsApps:/c/Users/78157/AppData/Local/Microsoft/WinGet/Packages/GitHub.Copilot_Microsoft.Winget.Source_8wekyb3d8bbwe:/c/Users/78157/AppData/Local/nvm:/c/nvm4w/nodejs:/c/Program Files/hurl:/usr/bin/vendor_perl:/usr/bin/core_perl:~/bin:~/bin:~/Workspaces/VsCode/lttatt-skill/bin:/c/Program Files/GitHub CLI:/c/Program Files/Docker/Docker/resources/bin"


git config --global init.defaultBranch master
git config --global alias.st status
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.co checkout
git config --global alias.pullm "pull origin master --tags --no-edit"
git config --global alias.pushm "push origin master --tags"
git config --global alias.pullo "pull origin"
git config --global alias.pusho "push origin"
git config --global alias.com "checkout master"
git config --global alias.cip "commit --allow-empty -m 'p'"
git config --global filter.lfs.process "git-lfs filter-process"
git config --global filter.lfs.required true
git config --global filter.lfs.clean "git-lfs clean -- %f"
git config --global filter.lfs.smudge "git-lfs smudge -- %f"
git config --global gui.encoding utf-8
git config --global core.autocrlf false
git config --global core.longpaths true
git config --global credential.helper store
