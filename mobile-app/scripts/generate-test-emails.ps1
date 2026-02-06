<#
.SYNOPSIS
    Generates test emails for spam filter testing after destructive operations

.DESCRIPTION
    Creates sample emails in a test email account to replenish test data after
    manual testing that deletes or moves emails. Useful for Sprint testing where
    readonly mode was not used and test emails were deleted.

.PARAMETER EmailProvider
    Email provider type: Gmail, AOL, Yahoo, Outlook
    Default: Gmail

.PARAMETER Count
    Number of test emails to generate
    Default: 50

.PARAMETER SpamRatio
    Percentage of emails that should be spam (0.0 to 1.0)
    Default: 0.7 (70% spam)

.PARAMETER CredentialsFile
    Path to secrets.dev.json containing email credentials
    Default: ../secrets.dev.json

.PARAMETER DryRun
    If set, shows what would be created without actually sending emails

.EXAMPLE
    .\generate-test-emails.ps1 -Count 100 -SpamRatio 0.8
    Generates 100 test emails (80 spam, 20 legitimate)

.EXAMPLE
    .\generate-test-emails.ps1 -DryRun
    Shows what would be created without sending

.NOTES
    Version: 1.0
    Date: February 1, 2026
    Author: Claude Sonnet 4.5

    IMPORTANT: This script requires an email account for testing.
    Do NOT use your personal email account - use a dedicated test account.
#>

param(
    [ValidateSet('Gmail', 'AOL', 'Yahoo', 'Outlook')]
    [string]$EmailProvider = 'Gmail',

    [ValidateRange(1, 1000)]
    [int]$Count = 50,

    [ValidateRange(0.0, 1.0)]
    [double]$SpamRatio = 0.7,

    [string]$CredentialsFile = "../secrets.dev.json",

    [switch]$DryRun
)

# Set UTF-8 encoding for Python scripts
$env:PYTHONIOENCODING = 'utf-8'

Write-Host "======================================"
Write-Host "Test Email Generator for Spam Filter"
Write-Host "======================================"
Write-Host ""

# Calculate email distribution
$spamCount = [int]($Count * $SpamRatio)
$legitimateCount = $Count - $spamCount

Write-Host "Configuration:"
Write-Host "  Provider: $EmailProvider"
Write-Host "  Total emails: $Count"
Write-Host "  Spam emails: $spamCount ($([int]($SpamRatio * 100))%)"
Write-Host "  Legitimate emails: $legitimateCount"
Write-Host "  Dry run: $DryRun"
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would generate the following test emails:"
    Write-Host ""
}

# Sample spam email templates
$spamTemplates = @(
    @{
        Subject = "URGENT: Your account will be closed!"
        From = "noreply@suspicious-bank.com"
        Body = "Dear customer, your account requires immediate verification. Click here to avoid suspension."
    },
    @{
        Subject = "You've won $1,000,000!"
        From = "lottery@winner-notification.net"
        Body = "Congratulations! You are the lucky winner of our international lottery. Claim your prize now!"
    },
    @{
        Subject = "Re: Invoice #12345"
        From = "billing@fake-company.biz"
        Body = "Please review the attached invoice and make payment within 24 hours to avoid late fees."
    },
    @{
        Subject = "Earn $5000/month working from home!"
        From = "jobs@work-from-home.info"
        Body = "No experience required! Start earning today with our proven system. Limited spots available!"
    },
    @{
        Subject = "Your package delivery failed"
        From = "delivery@not-real-ups.com"
        Body = "We attempted to deliver your package but no one was home. Click here to reschedule delivery."
    }
)

# Sample legitimate email templates
$legitimateTemplates = @(
    @{
        Subject = "Weekly team meeting notes"
        From = "colleague@example.com"
        Body = "Hi team, here are the notes from today's meeting. Let me know if you have any questions."
    },
    @{
        Subject = "Project update: Q1 2026"
        From = "manager@company.com"
        Body = "Great progress on the project this quarter. See attached report for details."
    },
    @{
        Subject = "Lunch next week?"
        From = "friend@gmail.com"
        Body = "Hey! Want to grab lunch next week? Let me know what day works for you."
    },
    @{
        Subject = "GitHub notification: New PR merged"
        From = "notifications@github.com"
        Body = "Pull request #112 has been successfully merged into develop branch."
    },
    @{
        Subject = "Newsletter: Tech Weekly"
        From = "newsletter@techweekly.com"
        Body = "This week's top stories: AI advances, new programming languages, and cloud security updates."
    }
)

# Function to generate email
function New-TestEmail {
    param(
        [hashtable]$Template,
        [int]$Index,
        [string]$Type
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $email = @{
        Index = $Index
        Type = $Type
        From = $Template.From
        Subject = $Template.Subject
        Body = $Template.Body
        Timestamp = $timestamp
    }

    return $email
}

# Generate spam emails
$generatedEmails = @()

for ($i = 1; $i -le $spamCount; $i++) {
    $template = $spamTemplates | Get-Random
    $email = New-TestEmail -Template $template -Index $i -Type "SPAM"
    $generatedEmails += $email

    if ($DryRun) {
        Write-Host "[$i] SPAM: $($email.Subject)"
    }
}

# Generate legitimate emails
for ($i = 1; $i -le $legitimateCount; $i++) {
    $template = $legitimateTemplates | Get-Random
    $email = New-TestEmail -Template $template -Index ($spamCount + $i) -Type "LEGITIMATE"
    $generatedEmails += $email

    if ($DryRun) {
        Write-Host "[$($spamCount + $i)] LEGITIMATE: $($email.Subject)"
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] No emails were actually sent."
    Write-Host ""
    Write-Host "To send these emails, run without -DryRun flag:"
    Write-Host "  .\generate-test-emails.ps1 -Count $Count -SpamRatio $SpamRatio"
    exit 0
}

# TODO: Implement actual email sending
# This would require SMTP library or email provider API
Write-Host ""
Write-Host "======================================"
Write-Host "IMPORTANT: Email sending not yet implemented"
Write-Host "======================================"
Write-Host ""
Write-Host "To implement email sending, you would need to:"
Write-Host "  1. Install SMTP library (e.g., System.Net.Mail in PowerShell)"
Write-Host "  2. Load credentials from $CredentialsFile"
Write-Host "  3. Connect to email provider SMTP server"
Write-Host "  4. Send emails using templates above"
Write-Host ""
Write-Host "For now, you can manually create test emails using the templates above."
Write-Host ""
Write-Host "Alternative approach:"
Write-Host "  - Use Gmail API to send emails programmatically"
Write-Host "  - Use test email service like Mailinator or Mailtrap"
Write-Host "  - Use IMAP APPEND command to directly insert emails (AOL, Yahoo)"
Write-Host ""

# Export email data to JSON for reference
$outputFile = "test-emails-$((Get-Date).ToString('yyyyMMdd-HHmmss')).json"
$generatedEmails | ConvertTo-Json -Depth 3 | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Email templates exported to: $outputFile"
Write-Host ""
Write-Host "You can use this file to:"
Write-Host "  1. Manually create test emails based on templates"
Write-Host "  2. Import into a Python script for automated sending"
Write-Host "  3. Reference when setting up test data"
Write-Host ""
