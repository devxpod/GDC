# Setting up MFA for the Identity Account.

Open a browser to the following URL: [https://YOURSITE.signin.aws.amazon.com/console](https://YOURSITE.signin.aws.amazon.com/console)  
Replacing YOURSITE with your site info.

Enter the username and password that were provided to you.

![login](./images/login.png "login")

On first login you may be prompted to change your password. (Note this login is separate from your SSO login. You may use same password if you want, just know that your SSO login and identity login are managed separately as well as MFA)

![change pw](./images/change_pw.png "change pw")

Your console will look like the picture below. Please click on the IAM service.

![select iam](./images/select_iam.png "select iam")

Click the "Add MFA" button. This will take you to the "My Security Credential" page where you will be able to change 
your IAM password, create and delete your AWS access key, and set up your MFA device.

![add mfa](./images/add_mfa.png "add mfa")

Click on the "Assign MFA device" button. This is very important as well as creating the Access key, otherwise, you won't 
be able to establish an AWS session via ssm-ssh.

![my sec creds](./images/my_sec_creds.png "my sec creds")

After you click the MFA device make your you select Virtual MFA device and click the continue button as shown below:

![manage mfa](./images/manage_mfa.png "manage mfa")

Click on the Show QR code, so you can scan it with your MFA Authenticator such as Microsoft Authenticator, DUO Mobile or Google Authenticator.

![show qr](./images/show_qr.png "show qr")

In this example I am using an iPhone to scan the QR code with DUO Mobile. The mfa.usr is an example.

Your username will appear here.

![mfa account name](./images/mfa_account_name.png "mfa account name")

Once you set IAM MFA account on your mobile type two consecutive MFA codes to finalize the MFA setup as shown below:

![mfa codes](./images/mfa_codes.png "mfa codes")

Your aws-identity MFA account would look similar to the following picture once you type the two consecutive codes.

![mfa app screen](./images/mfa_app_screen.png "mfa app screen")

Click on the close button

![close button](./images/close_button.png "close button")

# Creating AWS access keys

Click on the "Create access key" button

![my sec creds](./images/my_sec_creds.png "my sec creds")

A new set of AWS access keys will be generated. Click the "Download .csv file" button. *You must download before closing the screen. There is no way to retrieve the keys after the page is closed.*** 

![create access key](./images/new_access_key.png "create access key")

# Setting up local AWS credentials

Opening the csv file you downloaded from previous step should show something like the following: (note your values will be different)

![access keys](./images/access_keys.png "access keys")

In your home directory create a folder named ".aws" if you don't already have one.  
Then create or edit a file named credentials in that folder with the following structure:   
Replacing 
* mfa.user with your aws username.
* aws_access_key_id with value from csv in the "Access key ID" column.
* aws_secret_access_key with the value from csv in the "Secret access key" column. 

The localstack section should be kept as is.

```ini
[mfa.user-identity]
aws_access_key_id=AKIATHSY35ZK3P3YEGHZ
aws_secret_access_key=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

[localstack]
aws_access_key_id=test
aws_secret_access_key=test
```
Next create or edit a file named config in that folder with the following structure:
Replacing
* mfa.user with your aws username.

The localstack section should be kept as is.
```ini
[profile mfa.user-identity]
region=us-west-2
output=json

[profile localstack]
region=us-east-1
output=text
```

# Managing password, MFA, and access keys

Use the following link to update your password, MFA, and access keys:
[My security credentials](https://us-east-1.console.aws.amazon.com/iam/home#/security_credentials)

