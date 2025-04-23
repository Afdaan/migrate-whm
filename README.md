This script is a Bash utility designed to migrate emails, domains, and users into a single cPanel account.

## Features
- Migrates emails, domains, and users to a specified cPanel account.
- Automates the migration process to save time and reduce errors.

## Prerequisites
1. Ensure you have Bash installed on your system.
2. Verify that you have access to the source and destination cPanel accounts.
3. Make sure you have the necessary permissions to perform migrations.

## How to Run
1. Clone this repository to your local machine:
    ```bash
    git clone <repository-url>
    cd migrate_whm1
    ```
2. Make the script executable:
    ```bash
    chmod +x migrate_whm1.sh
    ```
3. Run the script with the required parameters:
    ```bash
    ./migrate_whm1.sh <source_account> <destination_account>
    ```
    Replace `<source_account>` and `<destination_account>` with the actual cPanel account details.

## Steps
1. **Prepare Source and Destination Accounts**: Ensure both accounts are accessible and have the necessary credentials.
2. **Run the Script**: Execute the script as described above.
3. **Verify Migration**: Check the destination account to confirm that all emails, domains, and users have been successfully migrated.
4. **Troubleshooting**: If any issues arise, review the script's output logs for details.

## Notes
- Always back up your data before performing migrations.
- This script is intended for specific use cases and may require customization for broader scenarios.
- For further assistance, refer to the official cPanel documentation or contact support.


