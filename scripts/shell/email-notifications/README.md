# Email Notifications Script

A robust bash script for sending bulk email notifications using the existing SMTP infrastructure.

## Overview

This script reads email addresses from a CSV file and sends notification emails using a markdown template. 
It's designed to run within existing service containers that already have SMTP configured, providing a simple solution for bulk email notifications.

## Features

- ✅ **Email validation** - Validates email format before sending
- ✅ **Duplicate detection** - Automatically skips duplicate email addresses
- ✅ **Dry-run mode** - Test functionality without actually sending emails
- ✅ **Progress tracking** - Shows progress for large email lists
- ✅ **Rate limiting** - Configurable delay between emails to avoid spam protection
- ✅ **Error handling** - Retry mechanism for failed emails with detailed logging
- ✅ **Statistics reporting** - Comprehensive summary of processing results
- ✅ **Flexible configuration** - Command-line options and environment variables

## Prerequisites

### System Requirements
- Linux container with bash shell
- `msmtp` command (msmtp package)
- Access to SMTP server (maildev or production SMTP)

### Files Required
- **CSV file** with email addresses (default: `/tmp/users.csv`)
- **Email template** in markdown format (default: `/tmp/email-template.md`)

### CSV Format
```csv
email
user1@example.com
user2@example.com
user3@example.com
```

**Note**: The CSV header is case-insensitive - both "email" and "EMAIL" are supported.

## Usage

### Basic Usage
```bash
# Run with default settings
./send-notifications.sh

# Dry run to test without sending emails
./send-notifications.sh --dry-run
```

### Command Line Options
```bash
./send-notifications.sh [OPTIONS]

Options:
    -c, --csv FILE          CSV file with email addresses (default: /tmp/users.csv)
    -t, --template FILE     Email template file (default: /tmp/email-template.md)
    -s, --subject SUBJECT   Email subject (default: "Discontinuation of the ORION Data Hub Service")
    -f, --from EMAIL        From email address (default: support@orionhub.io)
    -r, --rate-limit SEC    Seconds between emails (default: 2)
    -n, --dry-run          Don't actually send emails, just validate and show what would be sent
    --max-retries NUM      Maximum retry attempts for failed emails (default: 3)
    -v, --verbose          Enable verbose logging
    -h, --help             Show help message
```

### Environment Variables
```bash
export CSV_FILE="/tmp/users.csv"
export TEMPLATE_FILE="/tmp/email-template.md"
export DRY_RUN="true"
export RATE_LIMIT="5"
export MAX_RETRIES="2"
export EMAIL_SUBJECT="Custom Subject"
export FROM_EMAIL="noreply@example.com"
export SMTP_HOST="custom-smtp-host"
export SMTP_PORT="587"
export SMTP_USER="your_smtp_username"
export SMTP_PASSWORD="your_smtp_password"
```

## Docker Integration

### Running in Existing Service Container

The script is designed to run within existing service containers that already have SMTP configured.

#### Option 1: Copy script into running container
```bash
# Copy script to container
docker cp send-notifications.sh service-container:/
docker cp tmp/users.csv service-container:/tmp/
docker cp tmp/email-template.md service-container:/tmp/

# Execute in container
docker exec -it service-container /send-notifications.sh --dry-run
```

#### Option 2: Mount files as volumes
```bash
# Add volume mounts to existing service in docker-compose.yml
services:
  service:
    # ... existing configuration
    volumes:
      - "./scripts:/scripts"

# Restart service and run script
docker compose -f docker-compose.yml restart service-container
docker exec -it service-container /send-notifications.sh
```

## Configuration Examples

### Development Environment
```bash
# Test with local maildev
./send-notifications.sh \
    --dry-run \
    --csv /tmp/users.csv \
    --template /tmp/email-template.md \
    --rate-limit 1
```

### Production Environment
```bash
# Production SMTP settings
SMTP_HOST=smtp.gmail.com \
SMTP_PORT=587 \
FROM_EMAIL=noreply@xyz.org \
./send-notifications.sh \
    --csv /tmp/production-users.csv \
    --rate-limit 10 \
    --max-retries 5
```

### Large Email Lists
```bash
# For large lists, increase rate limiting to avoid spam protection
./send-notifications.sh \
    --csv /tmp/large-user-list.csv \
    --rate-limit 30 \
    --max-retries 5
```

## Monitoring and Logging

### Log Output Format
```
[2024-01-15 10:30:15] INFO: Starting Email Notifications Script
[2024-01-15 10:30:16] INFO: Found 150 valid unique email addresses
[2024-01-15 10:30:17] INFO: Processing 1/150: user@example.com
[2024-01-15 10:30:18] SUCCESS: Email sent successfully to: user@example.com
[2024-01-15 10:30:20] WARN: Attempt 1 failed for bad@example.com, retrying in 5 seconds...
[2024-01-15 10:30:35] ERROR: Failed to send email to bad@example.com after 3 retries
```

### Statistics Summary
```
=== EMAIL PROCESSING SUMMARY ===
Total emails processed: 150
Successfully sent: 147
Failed to send: 3
Duplicates skipped: 5
Invalid emails skipped: 2
Success rate: 98%
```

### Redirecting Logs
```bash
# Save logs to file
./send-notifications.sh 2>&1 | tee email-notifications.log

# Run in background with logging
nohup ./send-notifications.sh > email-notifications.log 2>&1 &
```

## Troubleshooting

### Common Issues

#### 1. "msmtp command not found"
```bash
# Install msmtp package
apt-get update && apt-get install -y msmtp
# or
yum install -y msmtp
```

#### 2. "Permission denied" error
```bash
# Make script executable
chmod +x send-notifications.sh
```

#### 3. SMTP connection failures
```bash
# Test SMTP connectivity
telnet maildev 1025

# Check SMTP settings with msmtp
echo "test" | msmtp --debug your@email.com
```

#### 4. "No valid emails found"
```bash
# Check CSV file format
head -5 users.csv
# Should show:
# email
# user1@example.com
# user2@example.com
```

#### 5. Template processing issues
```bash
# Verify template file exists and has content
cat email-template.md | wc -l
```

### Debugging

#### Enable verbose mode
```bash
./send-notifications.sh --verbose --dry-run
```

#### Manual testing
```bash
# Test single email manually with msmtp
echo -e "Subject: Test Subject\nFrom: from@example.com\nTo: to@example.com\n\nTest message" | msmtp --debug to@example.com
```

#### Check maildev interface
- Open http://localhost:1081 to see received emails in development

## Security Considerations

- The script does not store or log email content or addresses beyond runtime
- SMTP credentials are not hardcoded and should be provided via environment variables
- Use SMTP with authentication in production environments
- Consider using TLS/SSL for production SMTP connections

## Performance Notes

- Default rate limiting is 2 seconds between emails
- For large lists (>1000 emails), consider increasing rate limit to 10-30 seconds
- The script processes emails sequentially to maintain rate limiting
- Memory usage is minimal as emails are processed one at a time

## Script Validation

### Pre-flight Checks
The script performs comprehensive validation:
- ✅ Input files existence and readability
- ✅ Email address format validation
- ✅ Configuration parameter validation
- ✅ SMTP connectivity (via msmtp command availability)
- ✅ Template content validation

### Exit Codes
- `0` - Success (all emails sent or dry-run completed)
- `1` - Validation error or some emails failed
- `130` - Interrupted by user (Ctrl+C)

## Recent Updates

### Version 2.0 Changes
- **Replaced GNU mailutils with msmtp**: Better compatibility with MailDev authentication
- **Fixed bash arithmetic operations**: Compatible with `set -euo pipefail` strict mode
- **Improved CSV header handling**: Supports both "email" and "EMAIL" headers (case-insensitive)
- **Enhanced error handling**: More robust error reporting and debugging
- **Cleaned up logging**: Production-ready output with optional verbose mode

### Authentication Configuration
The script now uses msmtp with configurable SMTP authentication:
```bash
# Default MailDev credentials (can be overridden with environment variables)
SMTP_USER=maildev
SMTP_PASSWORD=xyz
SMTP_HOST=maildev
SMTP_PORT=1025
```

For production use, override these with your SMTP provider credentials:
```bash
export SMTP_USER="your_production_user"
export SMTP_PASSWORD="your_production_password"
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
```

## Integration with Services

This script is designed to work seamlessly with the existing infrastructure:

- **SMTP Integration**: Uses msmtp with MailDev authentication for development
- **Logging**: Compatible with Docker logging and monitoring
- **Security**: Respects existing authentication and authorization patterns
- **Deployment**: Can run within any existing service container

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Enable verbose mode for detailed debugging
3. Test with dry-run mode first
4. Verify msmtp configuration and MailDev connectivity
5. Check Docker logs for additional context

### Testing with MailDev
- MailDev web interface: http://localhost:1081
- All sent emails appear in the MailDev interface for testing
- No emails are actually delivered in development mode
