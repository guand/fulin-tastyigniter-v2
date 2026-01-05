#!/bin/bash
# Script to monitor TastyIgniter logs for media manager uploads

echo "=== TastyIgniter Log Monitor ==="
echo ""

# Check if container is running
if ! docker compose ps tastyigniter-app | grep -q "Up"; then
    echo "Error: tastyigniter-app container is not running"
    echo "Start it with: docker compose up -d"
    exit 1
fi

# Function to check and create log directory if needed
setup_logs() {
    echo "Checking log directory setup..."

    # Check if storage/logs directory exists
    if ! docker compose exec tastyigniter-app test -d /var/www/html/storage/logs; then
        echo "Creating storage/logs directory..."
        docker compose exec tastyigniter-app mkdir -p /var/www/html/storage/logs
        docker compose exec tastyigniter-app chmod -R 775 /var/www/html/storage/logs
        docker compose exec tastyigniter-app chown -R www-data:www-data /var/www/html/storage/logs
        echo "Log directory created successfully"
    fi

    # Check if log file exists, if not create it
    if ! docker compose exec tastyigniter-app test -f /var/www/html/storage/logs/laravel.log; then
        echo "Creating laravel.log file..."
        docker compose exec tastyigniter-app touch /var/www/html/storage/logs/laravel.log
        docker compose exec tastyigniter-app chmod 664 /var/www/html/storage/logs/laravel.log
        docker compose exec tastyigniter-app chown www-data:www-data /var/www/html/storage/logs/laravel.log
        echo "Log file created successfully"
    fi

    echo "Log setup complete!"
    echo ""
}

# Function to monitor specific log type
monitor_log() {
    local log_type=$1

    case $log_type in
        "app")
            echo "Monitoring Application Logs (Laravel)..."
            echo "Press Ctrl+C to stop"
            echo "---"
            docker compose exec tastyigniter-app tail -f /var/www/html/storage/logs/laravel.log
            ;;
        "apache-error")
            echo "Monitoring Apache Error Logs..."
            echo "Press Ctrl+C to stop"
            echo "---"
            docker compose exec tastyigniter-app tail -f /var/log/apache2/error.log
            ;;
        "apache-access")
            echo "Monitoring Apache Access Logs..."
            echo "Press Ctrl+C to stop"
            echo "---"
            docker compose exec tastyigniter-app tail -f /var/log/apache2/access.log
            ;;
        "docker")
            echo "Monitoring Docker Container Logs..."
            echo "Press Ctrl+C to stop"
            echo "---"
            docker compose logs -f tastyigniter-app
            ;;
        "all")
            echo "Showing recent logs from all sources..."
            echo ""
            echo "=== Docker Logs (last 20 lines) ==="
            docker compose logs --tail=20 tastyigniter-app
            echo ""
            echo "=== Application Logs (last 20 lines) ==="
            if docker compose exec tastyigniter-app test -f /var/www/html/storage/logs/laravel.log; then
                docker compose exec tastyigniter-app tail -n 20 /var/www/html/storage/logs/laravel.log
            else
                echo "No application logs found"
            fi
            echo ""
            echo "=== Apache Error Logs (last 20 lines) ==="
            docker compose exec tastyigniter-app tail -n 20 /var/log/apache2/error.log 2>/dev/null || echo "Apache logs not available"
            echo ""
            ;;
        "upload")
            echo "Monitoring Upload-Related Logs..."
            echo "Filtering for: upload, media, file, storage keywords"
            echo "Press Ctrl+C to stop"
            echo "---"
            if docker compose exec tastyigniter-app test -f /var/www/html/storage/logs/laravel.log; then
                docker compose exec tastyigniter-app tail -f /var/www/html/storage/logs/laravel.log | grep -i --line-buffered "upload\|media\|file\|storage"
            else
                echo "Log file not found. Creating it first..."
                setup_logs
                echo "Now monitoring for uploads..."
                docker compose exec tastyigniter-app tail -f /var/www/html/storage/logs/laravel.log | grep -i --line-buffered "upload\|media\|file\|storage"
            fi
            ;;
        *)
            echo "Unknown log type: $log_type"
            show_usage
            exit 1
            ;;
    esac
}

# Function to show usage
show_usage() {
    echo "Usage: ./monitor-logs.sh [option]"
    echo ""
    echo "Options:"
    echo "  app            - Monitor Laravel application logs"
    echo "  apache-error   - Monitor Apache error logs"
    echo "  apache-access  - Monitor Apache access logs"
    echo "  docker         - Monitor Docker container logs"
    echo "  upload         - Monitor upload-related logs (filtered)"
    echo "  all            - Show recent logs from all sources"
    echo "  setup          - Setup log directories and files"
    echo ""
    echo "Examples:"
    echo "  ./monitor-logs.sh upload       # Monitor upload activity"
    echo "  ./monitor-logs.sh app          # Monitor application logs"
    echo "  ./monitor-logs.sh all          # Show all recent logs"
}

# Main script logic
case ${1:-""} in
    "setup")
        setup_logs
        ;;
    "app"|"apache-error"|"apache-access"|"docker"|"all"|"upload")
        setup_logs  # Ensure logs are set up before monitoring
        monitor_log "$1"
        ;;
    "")
        # Default: monitor upload-related logs
        setup_logs
        monitor_log "upload"
        ;;
    "-h"|"--help"|"help")
        show_usage
        ;;
    *)
        echo "Error: Unknown option '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac
