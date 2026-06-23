The Account tab configures two special folders per account: the Safe Sender Folder and the Deleted Rule Folder. Both are optional -- leaving them blank falls back to provider defaults.

- Safe Sender Folder: destination for emails matched by a safe-sender rule. Typically the same folder where you already file "keep these" mail.
- Deleted Rule Folder: destination when a block rule's action is "move to folder" rather than delete. Useful for review-before-purge workflows.

Provider suggestions:
- Gmail: Safe -> INBOX (or a custom label like "Safe"); Deleted -> "[Gmail]/Trash" (soft delete) or a custom label like "Spam Candidates".
- AOL / Yahoo: Safe -> INBOX; Deleted -> "Bulk" or "Spam" (both are recognized as junk folders).
- Outlook.com: Safe -> Inbox; Deleted -> "Junk Email" or "Deleted Items".
- Generic IMAP: INBOX and Trash are nearly universal. Use the Folder Selection screen to see the exact names your server exposes.
