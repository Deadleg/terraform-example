# Terraform nginx example

This terraform configuration deploys an Ubuntu EC2 instance running NGINX in a Docker container in a public subnet.

Required parameters are

- `access_key`: AWS access key.
- `secret_key`: AWS secret key.
- `region`: AWS region to deploy to.

Terraform can then be run with

```bash
terraform apply -var 'access_key=####' -var 'secret_key=####' -var 'region=ap-southeast-2'
```

Both the security group and the IPTABLES configurations allow only TCP traffic into port 22 and 80.

The NGINX container can be reached publicly by `curl <IP of instance>` for the default home page and `curl <IP of instance>/output/usage` for the logs of the container usage.

The scripts are (numbering from the assignment):

- 8a: `health_check.sh`
- 8b: `home_page.sh`
- 8c: `check_usage.sh`

## Prequisites

Before terraform can be run the following needs to be setup:

- An AWS IAM user with the managed `AmazonEC2FullAccess` policy attached and a set of API credentials downloaded for this user.
- An EC2 key pair with the name `terraform-example` with the file `terraform-example.pem` placed in the root of this directory.

## Risks/issues

1. The `userdata` script used to provision the instance could fail (most likely due to a TCP during APT install or `curl`), and without any health checks or monitoring there is no automated recovery. Fix would be to use `packer` to create an AMI with all of the required configuration.
2. The `userdata` script downloads docker's gpg key with `curl | sudo` which can be dangerous if the server become compromised. Fix would be to download the key externally, verify it, then use that downloaded value during instance creation.
3. If the instance needs to be restarted or upgraded a re-deployment of the instance would need to happen, bringing down NGINX until it has restarted. Fix would be to use an auto scaling group (in a private subnet) and place the group behind the loadbalancer to allow for rolling deploys/blue-green etc.
4. By using variables for passing the access/secret keys you need to be careful not to expose the keys to git (by committing `tfvars`) or `ps aux` when specifying the parameters inline or environment variables with `env`. Fix would be to remove the variables and use the default AWS credentials chain, and to run Terraform on an EC2 instance with an appropriate IAM role to use short lived secret keys.
5. The IAM role allows all EC2 actions, which if comprimised would allow the attacker perform all actions to EC2 instances and VPC resources including deleting and creating any number of resources. Fix is to restrict the permissions for the user/role to only what is needed for the script to run.
6. Latest version of the ubuntu 16.04 AMI is used rather than a fixed version. During a future upgrade Ubuntu will be updated potentially breaking the startup scripts or other. Fix is the fix the Ubuntu AMI.
7. No CloudWatch alarms are defined so no notifications if something is out of the ordinary.
8. AWS does not provide metrics for disk usage or memory usage on an instance. Would need to deploy some solution (either AWS provided or third party like datadog) to allow for alarms to be created.
9. Using a t2 instance could have unexpected problems due to CPU credits. Depending on expected load it is safer to use another instance type for more stable CPU usage.
10. t2 instances have limited network bandwidth compared to larger instances if traffic is expected to reach such levels.
11. The `check_usage.sh` script will run forever, which will eventually use up all available disk space. Fix is to use something like log rotate to keep the logs at a consistant size.
12. Ubuntu automatically does downloads kernal updates in the background which can take up disk space.
13. The default logging for Docker is to log via JSON onto the hosts disk without log rotation, which will fill up the disk.
14. NGINX by default returns the NGINX version in the `Server` HTTP header. This can be disabled in the NGINX configuration
15. No HTTPS so everything is plain text. Even though no data is sent to the server, HTTPS can garauntee to some degree that the web page hasn't been tampered with.
