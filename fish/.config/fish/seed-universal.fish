# Curated snapshot of fish plugin universal-variable config (tide prompt,
# fish-exa, abbreviation-tips). Tracked so a fresh box can reproduce the prompt
# and aliases WITHOUT running `fisher install` (the installer vendors plugins
# and skips it, so the plugins' one-time `_install` events never fire — and
# tide's config lives in fish_variables, which is gitignored runtime state).
#
# Applied by bin/dotfiles-install's "fish plugins (fisher)" phase, only when
# tide is unconfigured (guarded on tide_left_prompt_items[1]), so it never
# clobbers a box you've since customized. Regenerate from a configured machine
# with `make seed-universal` (bin/dotfiles-seed-universal): it rewrites the
# tide_* block from this machine and preserves the trailing `set -Ux` block
# (fish-exa / abbr-tips) verbatim. The volatile _tide_prompt_* caches and *_files
# lists are deliberately excluded.
#
# Also deliberately excluded: the derived item caches _tide_left_items /
# _tide_right_items. tide rewrites these per-shell in fish_prompt via
# _tide_remove_unusable_items (from the tide_*_prompt_items config vars below,
# minus tools the machine lacks). Seeding them would (a) be redundant and (b)
# inject a stale snapshot into the live shell that ran `make install` — whose
# fish_prompt was already compiled for the unconfigured one-line state — making
# its one-line builder iterate items it can't render: `_tide_item_newline` (only
# defined in the two-line builder) and `_tide_item_kubectl` (kubectl absent)
# both throw "unknown command" until the next shell. Leaving them unset lets the
# next fresh shell compute them correctly per-machine.
set -U tide_aws_bg_color 303030
set -U tide_aws_color FF9900
set -U tide_aws_icon 
set -U tide_bun_bg_color 303030
set -U tide_bun_color FBF0DF
set -U tide_bun_icon 󰳓
set -U tide_character_color 5FD700
set -U tide_character_color_failure FF0000
set -U tide_character_icon ❯
set -U tide_character_vi_icon_default ❮
set -U tide_character_vi_icon_replace ▶
set -U tide_character_vi_icon_visual V
set -U tide_cmd_duration_bg_color 303030
set -U tide_cmd_duration_color 87875F
set -U tide_cmd_duration_decimals 0
set -U tide_cmd_duration_icon 
set -U tide_cmd_duration_threshold 3000
set -U tide_context_always_display false
set -U tide_context_bg_color 303030
set -U tide_context_color_default D7AF87
set -U tide_context_color_root D7AF00
set -U tide_context_color_ssh D7AF87
set -U tide_context_hostname_parts 1
set -U tide_crystal_bg_color 303030
set -U tide_crystal_color FFFFFF
set -U tide_crystal_icon 
set -U tide_direnv_bg_color 303030
set -U tide_direnv_bg_color_denied 303030
set -U tide_direnv_color D7AF00
set -U tide_direnv_color_denied FF0000
set -U tide_direnv_icon ▼
set -U tide_distrobox_bg_color 303030
set -U tide_distrobox_color FF00FF
set -U tide_distrobox_icon 󰆧
set -U tide_docker_bg_color 303030
set -U tide_docker_color 2496ED
set -U tide_docker_default_contexts default colima
set -U tide_docker_icon 
set -U tide_elixir_bg_color 303030
set -U tide_elixir_color 4E2A8E
set -U tide_elixir_icon 
set -U tide_gcloud_bg_color 303030
set -U tide_gcloud_color 4285F4
set -U tide_gcloud_icon 󰊭
set -U tide_git_bg_color 303030
set -U tide_git_bg_color_unstable 303030
set -U tide_git_bg_color_urgent 303030
set -U tide_git_color_branch 5FD700
set -U tide_git_color_conflicted FF0000
set -U tide_git_color_dirty D7AF00
set -U tide_git_color_operation FF0000
set -U tide_git_color_staged D7AF00
set -U tide_git_color_stash 5FD700
set -U tide_git_color_untracked 00AFFF
set -U tide_git_color_upstream 5FD700
set -U tide_git_icon 
set -U tide_git_truncation_length 24
set -U tide_git_truncation_strategy 
set -U tide_go_bg_color 303030
set -U tide_go_color 00ACD7
set -U tide_go_icon 
set -U tide_java_bg_color 303030
set -U tide_java_color ED8B00
set -U tide_java_icon 
set -U tide_jobs_bg_color 303030
set -U tide_jobs_color 5FAF00
set -U tide_jobs_icon 
set -U tide_jobs_number_threshold 1000
set -U tide_kubectl_bg_color 303030
set -U tide_kubectl_color 326CE5
set -U tide_kubectl_icon 󱃾
set -U tide_left_prompt_frame_enabled true
set -U tide_left_prompt_items vi_mode pwd git newline
set -U tide_left_prompt_prefix ''
set -U tide_left_prompt_separator_diff_color 
set -U tide_left_prompt_separator_same_color 
set -U tide_left_prompt_suffix 
set -U tide_nix_shell_bg_color 303030
set -U tide_nix_shell_color 7EBAE4
set -U tide_nix_shell_icon 
set -U tide_node_bg_color 303030
set -U tide_node_color 44883E
set -U tide_node_icon 
set -U tide_os_bg_color 303030
set -U tide_os_color EEEEEE
set -U tide_os_icon 
set -U tide_php_bg_color 303030
set -U tide_php_color 617CBE
set -U tide_php_icon 
set -U tide_private_mode_bg_color 303030
set -U tide_private_mode_color FFFFFF
set -U tide_private_mode_icon 󰗹
set -U tide_prompt_add_newline_before true
set -U tide_prompt_color_frame_and_connection 444444
set -U tide_prompt_color_separator_same_color 949494
set -U tide_prompt_icon_connection ─
set -U tide_prompt_min_cols 34
set -U tide_prompt_pad_items true
set -U tide_prompt_transient_enabled false
set -U tide_pulumi_bg_color 303030
set -U tide_pulumi_color F7BF2A
set -U tide_pulumi_icon 
set -U tide_pwd_bg_color 303030
set -U tide_pwd_color_anchors 00AFFF
set -U tide_pwd_color_dirs 0087AF
set -U tide_pwd_color_truncated_dirs 8787AF
set -U tide_pwd_icon 
set -U tide_pwd_icon_home 
set -U tide_pwd_icon_unwritable 
set -U tide_pwd_markers .bzr .citc .git .hg .node-version .python-version .ruby-version .shorten_folder_marker .svn .terraform bun.lockb Cargo.toml composer.json CVS go.mod package.json build.zig
set -U tide_python_bg_color 303030
set -U tide_python_color 00AFAF
set -U tide_python_icon 󰌠
set -U tide_right_prompt_frame_enabled true
set -U tide_right_prompt_items status cmd_duration context jobs direnv bun node python rustc java php pulumi ruby go gcloud kubectl distrobox toolbox terraform aws nix_shell crystal elixir zig time
set -U tide_right_prompt_prefix 
set -U tide_right_prompt_separator_diff_color 
set -U tide_right_prompt_separator_same_color 
set -U tide_right_prompt_suffix ''
set -U tide_ruby_bg_color 303030
set -U tide_ruby_color B31209
set -U tide_ruby_icon 
set -U tide_rustc_bg_color 303030
set -U tide_rustc_color F74C00
set -U tide_rustc_icon 
set -U tide_shlvl_bg_color 303030
set -U tide_shlvl_color d78700
set -U tide_shlvl_icon 
set -U tide_shlvl_threshold 1
set -U tide_status_bg_color 303030
set -U tide_status_bg_color_failure 303030
set -U tide_status_color 5FAF00
set -U tide_status_color_failure D70000
set -U tide_status_icon ✔
set -U tide_status_icon_failure ✘
set -U tide_terraform_bg_color 303030
set -U tide_terraform_color 844FBA
set -U tide_terraform_icon 󱁢
set -U tide_time_bg_color 303030
set -U tide_time_color 5F8787
set -U tide_time_format '%T'
set -U tide_toolbox_bg_color 303030
set -U tide_toolbox_color 613583
set -U tide_toolbox_icon 
set -U tide_vi_mode_bg_color_default 303030
set -U tide_vi_mode_bg_color_insert 303030
set -U tide_vi_mode_bg_color_replace 303030
set -U tide_vi_mode_bg_color_visual 303030
set -U tide_vi_mode_color_default 949494
set -U tide_vi_mode_color_insert 87AFAF
set -U tide_vi_mode_color_replace 87AF87
set -U tide_vi_mode_color_visual FF8700
set -U tide_vi_mode_icon_default D
set -U tide_vi_mode_icon_insert I
set -U tide_vi_mode_icon_replace R
set -U tide_vi_mode_icon_visual V
set -U tide_zig_bg_color 303030
set -U tide_zig_color F7A41D
set -U tide_zig_icon 
set -Ux ABBR_TIPS_PROMPT '\\n💡 \\e[1m{{ .abbr }}\\e[0m => {{ .cmd }}'
set -Ux ABBR_TIPS_REGEXES '(^(\\w+\\s+)+(-{1,2})\\w+)(\\s\\S+)' '(^(\\s?(\\w-?)+){3}).*' '(^(\\s?(\\w-?)+){2}).*' '(^(\\s?(\\w-?)+){1}).*'
set -Ux __ABBR_TIPS_KEYS 'g ga gaa gau gapa gap gb gba gban gbd gbD ggsup gbl gbs gbsb gbsg gbsr gbss gc gc! gcn! gca gca! gcan! gcv gcav gcav! gcm gcam gcs gscam gcfx gcf gcl gclean gclean! gclean!! gcount gcp gcpa gcpc gd gdca gds gdsc gdt gdw gdwc gdto gdg gignore gf gfa gfm gfo gl ggl gll glr glg glgg glgga glo glog gloga glom glod gloo gm gma gmt gmom gp gp! gpo gpo! gpv gpv! ggp ggp! gpu gpoat ggpnp gr gra grb grba grbc grbi grbm grbmi grbmia grbom grbomi grbomia grbd grbdi grbdia grbs ggu grev grh grhh grhpa grm grmc grmv grpo grrm grs grset grss grst grup grv gsh gsd gsr gsb gss gst gsta gstd gstl gstp gsts gsu gsur gsuri gts gtv gsw gswc gunignore gup gpr gupv gprv gupa gpra gupav gprav gprom gpromi gprum gprumi gwch gco gcb gcod gcom gfb gff gfr gfh gfs gfbs gffs gfrs gfhs gfss gfbt gfft gfrt gfht gfst gfp gwt gwta gwtls gwtlo gwtmv gwtpr gwtrm gwtulo gmr gmwps a__l a__la a__laa a__laad a__laai a__laaid a__lad a__lai a__laid a__lc a__lca a__lcaa a__lcaad a__lcaai a__lcaaid a__lcad a__lcai a__lcaid a__lcd a__lci a__lcid a__ld a__le a__lea a__leaa a__leaad a__leaai a__leaaid a__lead a__leai a__leaid a__led a__lei a__leid a__lg a__lga a__lgaa a__lgaad a__lgaai a__lgaaid a__lgad a__lgai a__lgaid a__lgd a__lgi a__lgid a__li a__lid a__ll a__lla a__llaa a__llaad a__llaai a__llaaid a__llad a__llai a__llaid a__lld a__lli a__llid a__lo a__loa a__loaa a__loaad a__loaai a__loaaid a__load a__loai a__loaid a__lod a__loi a__loid a__lt a__lta a__ltaad a__ltaai a__ltaaid a__ltad a__ltai a__ltaid a__ltd a__lti a__ltid'
set -Ux __ABBR_TIPS_VALUES 'git git add git add --all git add --update git add --patch git apply git branch -vv git branch -a -v git branch -a -v --no-merged git branch -d git branch -D git branch --set-upstream-to=origin/(__git.current_branch) git blame -b -w git bisect git bisect bad git bisect good git bisect reset git bisect start git commit -v git commit -v --amend git commit -v --no-edit --amend git commit -v -a git commit -v -a --amend git commit -v -a --no-edit --amend git commit -v --no-verify git commit -a -v --no-verify git commit -a -v --no-verify --amend git commit -m git commit -a -m git commit -S git commit -S -a -m git commit --fixup git config --list git clone git clean -di git clean -dfx git reset --hard; and git clean -dfx git shortlog -sn git cherry-pick git cherry-pick --abort git cherry-pick --continue git diff git diff --cached git diff --stat git diff --stat --cached git diff-tree --no-commit-id --name-only -r git diff --word-diff git diff --word-diff --cached git difftool git diff --no-ext-diff git update-index --assume-unchanged git fetch git fetch --all --prune git fetch origin (__git.default_branch) --prune; and git merge FETCH_HEAD git fetch origin git pull git pull origin (__git.current_branch) git pull origin git pull --rebase git log --stat git log --graph git log --graph --decorate --all git log --oneline --decorate --color git log --oneline --decorate --color --graph git log --oneline --decorate --color --graph --all git log --oneline --decorate --color (__git.default_branch).. git log --oneline --decorate --color develop.. "git log --pretty=format:\'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s\' --date=short" git merge git merge --abort git mergetool --no-prompt git merge origin/(__git.default_branch) git push git push --force-with-lease git push origin git push --force-with-lease origin git push --no-verify git push --no-verify --force-with-lease git push origin (__git.current_branch) git push origin (__git.current_branch) --force-with-lease git push origin (__git.current_branch) --set-upstream git push origin --all; and git push origin --tags git pull origin (__git.current_branch); and git push origin (__git.current_branch) git remote -vv git remote add git rebase git rebase --abort git rebase --continue git rebase --interactive git rebase (__git.default_branch) git rebase (__git.default_branch) --interactive git rebase (__git.default_branch) --interactive --autosquash git fetch origin (__git.default_branch); and git rebase FETCH_HEAD git fetch origin (__git.default_branch); and git rebase FETCH_HEAD --interactive git fetch origin (__git.default_branch); and git rebase FETCH_HEAD --interactive --autosquash git rebase develop git rebase develop --interactive git rebase develop --interactive --autosquash git rebase --skip git pull --rebase origin (__git.current_branch) git revert git reset git reset --hard git reset --patch git rm git rm --cached git remote rename git remote prune origin git remote remove git restore git remote set-url git restore --source git restore --staged git remote update git remote -v git show git svn dcommit git svn rebase git status -sb git status -s git status git stash git stash drop git stash list git stash pop git stash show --text git submodule update git submodule update --recursive git submodule update --recursive --init git tag -s git tag git switch git switch --create git update-index --no-assume-unchanged git pull --rebase git pull --rebase git pull --rebase -v git pull --rebase -v git pull --rebase --autostash git pull --rebase --autostash git pull --rebase --autostash -v git pull --rebase --autostash -v git pull --rebase origin (__git.default_branch) git pull --rebase=interactive origin (__git.default_branch) git pull --rebase upstream (__git.default_branch) git pull --rebase=interactive upstream (__git.default_branch) git log -p --abbrev-commit --pretty=medium --raw --no-merges git checkout git checkout -b git checkout (__git.develop_branch) git checkout (__git.default_branch) git flow bugfix git flow feature git flow release git flow hotfix git flow support git flow bugfix start git flow feature start git flow release start git flow hotfix start git flow support start git flow bugfix track git flow feature track git flow release track git flow hotfix track git flow support track git flow publish git worktree git worktree add git worktree list git worktree lock git worktree move git worktree prune git worktree remove git worktree unlock git push origin (__git.current_branch) --set-upstream -o merge_request.create git push origin (__git.current_branch) --set-upstream -o merge_request.create -o merge_request.merge_when_pipeline_succeeds eza $EXA_STANDARD_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LA_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAA_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAD_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAI_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAID_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAD_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAI_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAID_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LA_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAA_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAD_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAI_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAID_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAD_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAI_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAID_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LD_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LI_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LID_OPTIONS $EXA_LC_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LD_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LA_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAA_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAD_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAI_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAID_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAD_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAI_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAID_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LD_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LI_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LID_OPTIONS $EXA_LE_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LA_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAA_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAD_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAI_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAID_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAD_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAI_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAID_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LD_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LI_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LID_OPTIONS $EXA_LG_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LI_OPTIONS $EXA_L_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LID_OPTIONS $EXA_L_OPTIONS exa_git exa_git $EXA_LA_OPTIONS exa_git $EXA_LAA_OPTIONS exa_git $EXA_LAAD_OPTIONS exa_git $EXA_LAAI_OPTIONS exa_git $EXA_LAAID_OPTIONS exa_git $EXA_LAD_OPTIONS exa_git $EXA_LAI_OPTIONS exa_git $EXA_LAID_OPTIONS exa_git $EXA_LD_OPTIONS exa_git $EXA_LI_OPTIONS exa_git $EXA_LID_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LA_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAA_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAD_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAI_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAID_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAD_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAI_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAID_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LD_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LI_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LID_OPTIONS $EXA_LO_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LA_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAD_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAI_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAAID_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAD_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAI_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LAID_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LD_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LI_OPTIONS $EXA_LT_OPTIONS eza $EXA_STANDARD_OPTIONS $EXA_LID_OPTIONS $EXA_LT_OPTIONS'
set -Ux __FISH_EXA_ALIASES l la ld li lid laa lad lai laid laad laai laaid ll lla lld lli llid llaa llad llai llaid llaad llaai llaaid lg lga lgd lgi lgid lgaa lgad lgai lgaid lgaad lgaai lgaaid le lea led lei leid leaa lead leai leaid leaad leaai leaaid lt lta ltd lti ltid ltad ltai ltaid ltaad ltaai ltaaid lc lca lcd lci lcid lcaa lcad lcai lcaid lcaad lcaai lcaaid lo loa lod loi loid loaa load loai loaid loaad loaai loaaid
set -Ux __FISH_EXA_BASE_ALIASES l ll lg le lt lc lo
set -Ux __FISH_EXA_BINARY eza
set -Ux __FISH_EXA_EXPANDED a d i id aa ad ai aid aad aai aaid
set -Ux __FISH_EXA_EXPANDED_OPT_NAME LA LD LI LID LAA LAD LAI LAID LAAD LAAI LAAID
set -Ux __FISH_EXA_OPT_NAMES EXA_L_OPTIONS EXA_LA_OPTIONS EXA_LD_OPTIONS EXA_LI_OPTIONS EXA_LID_OPTIONS EXA_LAA_OPTIONS EXA_LAD_OPTIONS EXA_LAI_OPTIONS EXA_LAID_OPTIONS EXA_LAAD_OPTIONS EXA_LAAI_OPTIONS EXA_LAAID_OPTIONS EXA_LL_OPTIONS EXA_LG_OPTIONS EXA_LE_OPTIONS EXA_LT_OPTIONS EXA_LC_OPTIONS EXA_LO_OPTIONS
set -Ux __FISH_EXA_SORT_OPTIONS name .name size ext mod old acc cr inode
