CURRENT_DIR=$(dirname "$0")
PARENT_DIR=$(dirname "$CURRENT_DIR")
TARGET_FILE="$PARENT_DIR/config/.env.exs"

if [ -f "$TARGET_FILE" ]; then
  exit
fi

RANDOM_SECRET_KEY_BASE=$(head -c 66 /dev/urandom | base64 -w 0)
echo "System.put_env(\"SECRET_KEY_BASE\", \"$RANDOM_SECRET_KEY_BASE\")" > $TARGET_FILE
