# hello_world 0.0.1
## Description
### infrastructure.rb
This is an AWS CloudFormation stack written in Kumogata's Ruby DSL with an auto-scaling application running a small 'hello world' Go application deployed automatically with Chef.

### hw_goapp
There is a Chef cookbook in `site-cookbooks` called hw_goapp. This will automatically deploy any go application included in node['go']['packages'] and as an init file and run it under the username provided in node['go']['owner'].

## Reference

### Setup
- `bundle install` to retrieve all dependencies
- If you'd like to change the app that is deployed, edit node.json with the appropriate 'go get' source package.
- Make sure your app listens on port 8484!

### Deploy
`kumogata create infrastructure.rb -r $REGION -p KeyName=$AWS_KEY_NAME[AppType=$APP_TYPE,AppGroupSize=$APP_SIZE,AppMaxSize=$APP_MAX_SIZE,SSHLocation=$SSH_CIDR,ChefRepoURL=$CHEF_REPOURL,ChefRepoBranch=$CHEF_REPOBRANCH,ChefRepo=$CHEF_REPO]`

Optional parameters are in square brackets, refer to the list below for a description of each. Once this is complete, `kumogata update` can be used with the stack's name and aforementioned parameters to make changes or `kumogata delete` with the stack's name to remove it.

### Parameters
- `$REGION` - AWS Region (eg. eu-west-1). Deployments are multi-AZ within EC2 (no VPC).
- `$APP_TYPE` - Size of the application instance. For a list of supported sizes, refer to infrastructure.rb (default m3.medium).
- `$APP_SIZE` - Default and preferred size of the auto-scaling group, in instances (default 1).
- `$APP_MAX_SIZE` - Maximum size of the autoscaling group, in instances (default 1).
- `$SSH_CIDR` - CIDR mask of the network from which you'll SSH. Default permits all IPs (0.0.0.0/0).
- `$CHEF_REPOURL` - The URL prefix of your repository (eg. the default is https://github.com/cvlc/)
- `$CHEF_REPO` - The name of the git repository that appears after the URL prefix (eg. hello_world)
- `$CHEF_REPOBRANCH` - The branch of the git repository (eg. master)

## TODO
- Add cfn-hup hook so chef-solo is automatically triggered on updates (currently, you need to kick it on existing instances or rescale them)
- Automate DNS management with Route53
- Split out repositories for Chef, app, etc.
- Split out hw_goapp cookbook into it's own repository and genericize it.
- Support VPC configurations
- Add automatic scaling and alerting with Cloudwatch
- Add more possible instance types
- Add support for custom load-balancers (eg. nginx, vulcand)
- Integrate automatic route53 management
- Integrate into CI/CD systems like Jenkins/Bamboo

## License

MIT Expat
