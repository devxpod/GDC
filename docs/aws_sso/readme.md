# AWS SSO LOG IN Process

You should receive an AWS invite email in your inbox once your SSO account is created that will look as follows:

![email subject](./images/invite-email-subject.png "email subject")

![email body](./images/invite-email-body.png "email body")

Once you click on the accept invitation you will be directed to create a new password as shown below:

![new user](./images/aws_new_user.png "new user")

To log into AWS SSO please go to this website: [https://YOURSITE.awsapps.com/start](https://YOURSITE.awsapps.com/start)  
Replace YOURSITE with your correct url.

You will be directed to the logon page where you will be entering your username in the recommended format: firstname.lastname.

Example:

![login](./images/aws_login.png "login")

In the next page, you will be asked to register your MFA (Multi Factor Authenticator) device to access your AWS account.

![new mfa](./images/aws_new_mfa.png "new mfa")

You can use any MFA authenticator such as DUO Mobile, Microsoft Authenticator, Google Authenticator to add the AWS MFA account with QR Code as shown below:

![mfa qr](./images/aws_mfa_qr.png "mfa qr")

![mfa name](./images/aws_mfa_name.png "mfa name")


This is how it looks in DUO after you type the name of the account:

![mfa done](./images/aws_mfa_done.png "mfa done")

Once you type the MFA code it may ask you to reset the password if this is your first logging into AWS SSO.
