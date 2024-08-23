#!/bin/bash

[ -z "$REDIS_FQDN" ] && REDIS_FQDN=redis

term_proc() {
    echo "Entrypoint FPM caught SIGTERM signal!"
    echo "Killing process $master_pid"
    kill -TERM "$master_pid" 2>/dev/null
}

trap term_proc SIGTERM

change_php_vars() {
    for FILE in /etc/php/*/fpm/php.ini
    do
        [[ -e $FILE ]] || break
        sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT:-2048M}/" "$FILE"
        sed -i "s/max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION_TIME:-300}/" "$FILE"
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE:-50M}/" "$FILE"
        sed -i "s/post_max_size = .*/post_max_size = ${PHP_POST_MAX_SIZE:-50M}/" "$FILE"
        sed -i "s/session.save_handler = .*/session.save_handler = redis/" "$FILE"
        sed -i "s|.*session.save_path = .*|session.save_path = '$(echo $REDIS_FQDN | grep -E '^\w+://' || echo tcp://$REDIS_FQDN):6379${REDIS_PASSWORD:+?auth=${REDIS_PASSWORD}}'|" "$FILE"
        sed -i "s/session.sid_length = .*/session.sid_length = 64/" "$FILE"
        sed -i "s/session.use_strict_mode = .*/session.use_strict_mode = 1/" "$FILE"

        # sed -i 's|;*max_input_time\s*=.*|max_input_time = 3000|' /etc/php/7.4/fpm/php.ini
        sed -i "s|;*max_input_time\s*=.*|max_input_time = $PHP_MAX_INPUT_TIME|" "$FILE"

        # sed -i 's|;*max_execution_time\s*=.*|max_execution_time = 3000|' /etc/php/7.4/fpm/php.ini
        sed -i "s|;*max_execution_time\s*=.*|max_execution_time = $PHP_MAX_EXECUTION_TIME|" "$FILE"

    done
}

echo "Configure PHP | Change PHP values ..." && change_php_vars

echo "Configure PHP | Starting PHP FPM"
/usr/sbin/php-fpm7.4 -R -F & master_pid=$!

# Wait for it
wait "$master_pid"
