#!/bin/bash

# Email Notifications Script for Discontinuation of the ORION Data Hub Service
# Sends notification emails to users listed in CSV file

set -euo pipefail

# Configuration defaults
CSV_FILE="${CSV_FILE:-/tmp/users.csv}"
TEMPLATE_FILE="${TEMPLATE_FILE:-/tmp/email-template.md}"
DRY_RUN="${DRY_RUN:-false}"
RATE_LIMIT="${RATE_LIMIT:-2}"  # seconds between emails
MAX_RETRIES="${MAX_RETRIES:-3}"
EMAIL_SUBJECT="${EMAIL_SUBJECT:-Discontinuation of the ORION Data Hub Service}"
FROM_EMAIL="${FROM_EMAIL:-support@orionhub.io}"
SMTP_HOST="${SMTP_HOST:-maildev}"
SMTP_PORT="${SMTP_PORT:-1025}"
SMTP_USER="${SMTP_USER:-maildev}"
SMTP_PASSWORD="${SMTP_PASSWORD:-xyz}"

# Counters for statistics
TOTAL_EMAILS=0
SENT_SUCCESS=0
SENT_FAILED=0
DUPLICATES_SKIPPED=0
INVALID_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_info() {
    log "${BLUE}INFO${NC}: $*"
}

log_warn() {
    log "${YELLOW}WARN${NC}: $*"
}

log_error() {
    log "${RED}ERROR${NC}: $*"
}

log_success() {
    log "${GREEN}SUCCESS${NC}: $*"
}

# Help function
show_help() {
    cat << EOF
Email Notifications Script

Usage: $0 [OPTIONS]

Options:
    -c, --csv FILE          CSV file with email addresses (default: /tmp/users.csv)
    -t, --template FILE     Email template file (default: /tmp/email-template.md)
    -s, --subject SUBJECT   Email subject (default: "Discontinuation of the ORION Data Hub Service")
    -f, --from EMAIL        From email address (default: support@orionhub.io)
    -r, --rate-limit SEC    Seconds between emails (default: 2)
    -n, --dry-run          Don't actually send emails, just validate and show what would be sent
    --max-retries NUM      Maximum retry attempts for failed emails (default: 3)
    -v, --verbose          Enable verbose logging
    -h, --help             Show this help message

Environment Variables:
    CSV_FILE               Path to CSV file
    TEMPLATE_FILE          Path to email template
    DRY_RUN               Set to 'true' for dry run mode
    RATE_LIMIT            Seconds between emails
    MAX_RETRIES           Maximum retry attempts
    EMAIL_SUBJECT         Email subject line
    FROM_EMAIL            From email address
    SMTP_HOST            SMTP server hostname (default: maildev)
    SMTP_PORT            SMTP server port (default: 1025)
    SMTP_USER            SMTP username (default: maildev)
    SMTP_PASSWORD        SMTP password (default: xyz)

Examples:
    # Basic usage
    $0

    # Dry run to test without sending
    $0 --dry-run

    # Custom files and settings
    $0 -c /custom/users.csv -t /custom/template.md --rate-limit 5

    # Using environment variables
    DRY_RUN=true CSV_FILE=/tmp/test-users.csv $0
EOF
}

# Email validation function
is_valid_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--csv)
                CSV_FILE="$2"
                shift 2
                ;;
            -t|--template)
                TEMPLATE_FILE="$2"
                shift 2
                ;;
            -s|--subject)
                EMAIL_SUBJECT="$2"
                shift 2
                ;;
            -f|--from)
                FROM_EMAIL="$2"
                shift 2
                ;;
            -r|--rate-limit)
                RATE_LIMIT="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate input files and configuration
validate_inputs() {
    log_info "Validating input files and configuration..."

    if [[ ! -f "$CSV_FILE" ]]; then
        log_error "CSV file not found: $CSV_FILE"
        exit 1
    fi

    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi

    if [[ ! "$RATE_LIMIT" =~ ^[0-9]+$ ]] || [[ "$RATE_LIMIT" -lt 0 ]]; then
        log_error "Invalid rate limit: $RATE_LIMIT (must be non-negative integer)"
        exit 1
    fi

    if [[ ! "$MAX_RETRIES" =~ ^[0-9]+$ ]] || [[ "$MAX_RETRIES" -lt 0 ]]; then
        log_error "Invalid max retries: $MAX_RETRIES (must be non-negative integer)"
        exit 1
    fi

    if ! is_valid_email "$FROM_EMAIL"; then
        log_error "Invalid from email address: $FROM_EMAIL"
        exit 1
    fi

    # Check if msmtp command is available
    if ! command -v msmtp >/dev/null 2>&1; then
        log_error "msmtp command not found. Please install msmtp package."
        exit 1
    fi

    log_success "Input validation completed successfully"
}

# Read and validate CSV file
read_csv_emails() {
    local emails=()
    local seen_emails=()
    local line_num=0

    log_info "Reading and validating emails from CSV file: $CSV_FILE"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))

        # Skip header line
        if [[ $line_num -eq 1 ]]; then
            line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n')
            if [[ "$line_lower" == "email" ]]; then
                : # Header line - skip
            else
                log_warn "Line $line_num: Expected 'email' header, got: '$line'"
            fi
        else
            # Clean and extract email
            email=$(echo "$line" | tr -d ' \t\r\n,' | tr '[:upper:]' '[:lower:]')

            # Skip empty lines
            if [[ -n "$email" ]]; then
                # Validate email format
                if is_valid_email "$email"; then
                    # Check for duplicates
                    if [[ " ${seen_emails[*]} " =~ " ${email} " ]]; then
                        log_warn "Line $line_num: Duplicate email skipped: $email"
                        DUPLICATES_SKIPPED=$((DUPLICATES_SKIPPED + 1))
                    else
                        emails+=("$email")
                        seen_emails+=("$email")
                        TOTAL_EMAILS=$((TOTAL_EMAILS + 1))
                    fi
                else
                    log_warn "Line $line_num: Invalid email format: '$email'"
                    INVALID_SKIPPED=$((INVALID_SKIPPED + 1))
                fi
            fi
        fi
    done < "$CSV_FILE"

    if [[ ${#emails[@]} -eq 0 ]]; then
        log_error "No valid emails found in CSV file"
        exit 1
    fi

    log_info "Found ${#emails[@]} valid unique email addresses"
    [[ $DUPLICATES_SKIPPED -gt 0 ]] && log_info "Skipped $DUPLICATES_SKIPPED duplicate emails"
    [[ $INVALID_SKIPPED -gt 0 ]] && log_info "Skipped $INVALID_SKIPPED invalid emails"

    printf '%s\n' "${emails[@]}"
}

# Process email template
process_template() {
    log_info "Processing email template: $TEMPLATE_FILE"

    if [[ ! -s "$TEMPLATE_FILE" ]]; then
        log_error "Template file is empty: $TEMPLATE_FILE"
        exit 1
    fi

    # Convert markdown to plain text (basic conversion)
    local email_body
    email_body=$(sed 's/^#* *//' "$TEMPLATE_FILE" | sed 's/\*\*\(.*\)\*\*/\1/g' | sed 's/\*\(.*\)\*/\1/g')

    if [[ -z "$email_body" ]]; then
        log_error "Processed template is empty"
        exit 1
    fi

    log_success "Email template processed successfully"
    echo "$email_body"
}

# Send email with retry logic
send_email_with_retry() {
    local email="$1"
    local body="$2"
    local attempt=1
    local max_attempts=$((MAX_RETRIES + 1))

    while [[ $attempt -le $max_attempts ]]; do
        if send_single_email "$email" "$body"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Attempt $attempt failed for $email, retrying in 5 seconds..."
            sleep 5
        fi

        attempt=$((attempt + 1))
    done

    log_error "Failed to send email to $email after $MAX_RETRIES retries"
    return 1
}

# Send single email
send_single_email() {
    local email="$1"
    local body="$2"

    # Configure msmtp for SMTP with authentication
    cat > "/tmp/.msmtprc" << EOF
defaults
tls off
tls_starttls off

account default
host ${SMTP_HOST}
port ${SMTP_PORT}
auth plain
user ${SMTP_USER}
password ${SMTP_PASSWORD}
from ${FROM_EMAIL}
EOF
    chmod 600 "/tmp/.msmtprc"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would send email to: $email"
        return 0
    fi

    # Send email using msmtp
    if echo -e "Subject: $EMAIL_SUBJECT\nFrom: $FROM_EMAIL\nTo: $email\n\n$body" | msmtp --file=/tmp/.msmtprc "$email"; then
        return 0
    else
        return 1
    fi
}

# Main processing function
process_emails() {
    local -a emails
    
    # Use alternative method to populate array
    local email_list
    email_list=$(read_csv_emails)
    
    if [[ -n "$email_list" ]]; then
        readarray -t emails <<< "$email_list"
    else
        emails=()
    fi
    

    local email_body
    email_body=$(process_template)

    log_info "Starting email processing..."
    [[ "$DRY_RUN" == "true" ]] && log_info "DRY-RUN MODE: No emails will actually be sent"

    local current=0
    for email in "${emails[@]}"; do
        current=$((current + 1))

        log_info "Processing $current/${#emails[@]}: $email"

        if send_email_with_retry "$email" "$email_body"; then
            log_success "Email sent successfully to: $email"
            SENT_SUCCESS=$((SENT_SUCCESS + 1))
        else
            log_error "Failed to send email to: $email"
            SENT_FAILED=$((SENT_FAILED + 1))
        fi

        # Rate limiting (except for last email)
        if [[ $current -lt ${#emails[@]} ]] && [[ "$RATE_LIMIT" -gt 0 ]]; then
            log_info "Waiting ${RATE_LIMIT} seconds before next email..."
            sleep "$RATE_LIMIT"
        fi
    done
}

# Print final statistics
print_statistics() {
    log_info "=== EMAIL PROCESSING SUMMARY ==="
    log_info "Total emails processed: $TOTAL_EMAILS"
    log_info "Successfully sent: $SENT_SUCCESS"
    log_info "Failed to send: $SENT_FAILED"
    log_info "Duplicates skipped: $DUPLICATES_SKIPPED"
    log_info "Invalid emails skipped: $INVALID_SKIPPED"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Mode: DRY-RUN (no emails were actually sent)"
    fi

    local total_processed=$((SENT_SUCCESS + SENT_FAILED))
    if [[ $total_processed -gt 0 ]]; then
        local success_rate=$((SENT_SUCCESS * 100 / total_processed))
        log_info "Success rate: ${success_rate}%"
    fi
}

# Cleanup function
cleanup() {
    [[ -f "/tmp/.mailrc" ]] && rm -f "/tmp/.mailrc"
}

# Signal handlers
trap cleanup EXIT
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Main function
main() {
    log_info "Starting Email Notifications Script"
    log_info "Configuration:"
    log_info "  CSV File: $CSV_FILE"
    log_info "  Template File: $TEMPLATE_FILE"
    log_info "  From Email: $FROM_EMAIL"
    log_info "  Subject: $EMAIL_SUBJECT"
    log_info "  Rate Limit: ${RATE_LIMIT}s"
    log_info "  Max Retries: $MAX_RETRIES"
    log_info "  Dry Run: $DRY_RUN"
    log_info "  SMTP: ${SMTP_HOST}:${SMTP_PORT}"
    log_info "  SMTP User: $SMTP_USER"
    log_info "  SMTP Password: ${SMTP_PASSWORD:0:3}***"

    validate_inputs
    process_emails
    print_statistics

    if [[ $SENT_FAILED -gt 0 ]]; then
        log_error "Some emails failed to send. Check logs above for details."
        exit 1
    else
        log_success "Email processing completed successfully!"
        exit 0
    fi
}

# Parse arguments and run main function
parse_args "$@"
main
