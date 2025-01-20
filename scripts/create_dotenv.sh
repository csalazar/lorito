RANDOM_SECRET_KEY_BASE=$(head -c 66 /dev/urandom | base64 -w 0)
echo "System.put_env(\"SECRET_KEY_BASE\", \"$RANDOM_SECRET_KEY_BASE\")" > config/.env.exs
