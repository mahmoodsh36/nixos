echo "$WORK_DIR"
echo "$MAIN_USER"
for repo in otherdots nvim scripts arch awesome nixos .emacs.d; do
    if [ ! -d "$WORK_DIR/$repo" ]; then
        remote="$MYGITHUB/$repo"
        echo cloning $remote
        cd "$WORK_DIR"
        git clone $remote
    fi
    echo restoring $repo
    cd "$WORK_DIR/$repo"
    ./restore.sh
done