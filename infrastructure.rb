AWSTemplateFormatVersion "2010-09-09"
Description "Creates and deployes an auto-scaling group for a Go webapp with associated ELB and bootstraps nodes with Chef automatically"
Parameters do
  KeyName do
    Description "Name of an EC2 keypair to enable SSH access"
    Type "String"
  end
  AppType do
    Description "App instance type"
    Type "String"
    Default "m3.medium"
    AllowedValues "m4.large", "m3.medium", "m3.large", "m3.xlarge", "m3.2xlarge", "c3.2xlarge"
    ConstraintDescription "must be a valid EC2 instance type."
  end
  AppGroupSize do
    Default 1
    Description "The default number of EC2 instances for the app cluster"
    Type "Number"
  end
  AppMaxSize do
    Default 1
    Description "The maximum number of EC2 instances for the app cluster"
    Type "Number"
  end
  SSHLocation do
    Description "The IP address range that can be used to SSH to the EC2 instances"
    Type "String"
    MinLength 9
    MaxLength 18
    Default "0.0.0.0/0"
    AllowedPattern "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})"
    ConstraintDescription "must be a valid IP CIDR range of the form x.x.x.x/x."
  end
  ChefRepoBranch do
    Description "The branch of the git repository from which to deploy the app server"
    Type "String"
    Default "master"
  end
  ChefRepo do
    Description "The name of the git repository from which to deploy the app server"
    Type "String"
    Default "hello_world"
  end
  ChefRepoURL do
    Description "The prefix URL of the git repository from which to deploy the app server"
    Type "String"
    Default "https://github.com/cvlc/" 
  end
end
Mappings do
  AWSInstanceType2Arch(
     {"m4.large"=>{"Arch"=>"64"},
     "m3.medium"=>{"Arch"=>"64HVM"},
     "m3.large"=>{"Arch"=>"64HVM"},
     "m3.xlarge"=>{"Arch"=>"64HVM"},
     "m3.2xlarge"=>{"Arch"=>"64HVM"},
     "c3.2xlarge"=>{"Arch"=>"64HVM"}})
  AWSRegionArch2AMI(
    {"us-east-1"=>
      {"64"=>"ami-a0aceeca", "64HVM"=>"ami-e6b8fa8c"},
     "us-west-2"=>
      {"64"=>"ami-e02e3c81", "64HVM"=>"ami-d5d2c0b4"},
     "us-west-1"=>
      {"64"=>"ami-f6dfb696", "64HVM"=>"ami-44deb724"},
     "eu-west-1"=>
      {"64"=>"ami-391cbb4a", "64HVM"=>"ami-f81abd8b"},
     "ap-southeast-1"=>
      {"64"=>"ami-b9cc0cda", "64HVM"=>"ami-f9ce0e9a"},
     "ap-southeast-2"=>
      {"64"=>"ami-f95d059a", "64HVM"=>"ami-245c0447"},
     "ap-northeast-1"=>
      {"64"=>"ami-baf3dcd4", "64HVM"=>"ami-dcf3dcb2"},
     "sa-east-1"=>
      {"64"=>"ami-840184e8", "64HVM"=>"ami-0b0f8a67"}})
end
Resources do
  AppServerLB do
    Type "AWS::ElasticLoadBalancing::LoadBalancer"
    Properties do
      CrossZone "true"
      AvailabilityZones do
        Fn__GetAZs do
          Ref "AWS::Region"
        end
      end
      HealthCheck do 
        HealthyThreshold 2
        UnhealthyThreshold 2
        Interval 20
        Timeout 10
        Target "TCP:8484"
      end
      Listeners [
        _{
          InstancePort 8484
          LoadBalancerPort 80
          Protocol "HTTP"
          InstanceProtocol "HTTP"
         } 
      ]
    end
  end
  AppServerGroup do
    Type "AWS::AutoScaling::AutoScalingGroup"
    Properties do
      LoadBalancerNames [
        _{ Ref "AppServerLB" }
      ]
      LaunchConfigurationName do
        Ref "AppLaunchConfig"
      end
      AvailabilityZones do
        Fn__GetAZs do
          Ref "AWS::Region"
        end
      end
      MinSize 0
      MaxSize do
        Ref "AppMaxSize"
      end
      DesiredCapacity do
        Ref "AppGroupSize"
      end
    end
  end
  AppLaunchConfig do
    Type "AWS::AutoScaling::LaunchConfiguration"
    Metadata do
      AWS__CloudFormation__Init do
        configSets do
            chef [ "configureSet", "prepareSet", "installSet" ]
        end
        configureSet do
          files do
            _path("/etc/chef/solo.rb") do
              content do
                Fn__Join [ "",
                [
                  "\n",
                  "log_level :info\n", 
                  "log_location STDOUT\n", 
                  "file_cache_path \"/var/chef-solo\"\n", 
                  "cookbook_path [ \"/var/chef-solo/cookbooks\",\n",
                  "                \"/var/chef-solo/site-cookbooks\" ]\n", 
                  "json_attribs \"",
                  _{ Ref "ChefRepoURL" },
                  _{ Ref "ChefRepo" },
                  "/raw/",
                  _{ Ref "ChefRepoBranch" },
                  "/node.json",
                  "\"\n", 
                ] ]
              end
              mode "000644"
              owner "root"
              group "sudo"
            end
          end
        end
        prepareSet do
          commands do
            prepare_chef_solo do
              command do
                Fn__Join [ "",
                [ "wget -O - ",
                  _{ Ref "ChefRepoURL" },
                  "/",
                  _{ Ref "ChefRepo" },
                  "/archive/",
                  _{ Ref "ChefRepoBranch" },
                  ".tar.gz | tar --strip-components=1 -C /var/chef-solo -xvzf -" 
                ] ]
              end
            end
          end
        end
        installSet do
          commands do
            install_cookbooks do
              command "HOME=/root librarian-chef install"
              cwd "/var/chef-solo"
            end
          end
        end
      end
    end
    Properties do
      InstanceType do
        Ref "AppType"
      end
      SecurityGroups [
        _{
          Ref "SSHGroup"
        },
        _{
          Ref "AppGroup"
        }
      ]
      ImageId do
        Fn__FindInMap [
          "AWSRegionArch2AMI",
          _{
            Ref "AWS::Region"
          },
          _{
            Fn__FindInMap [
              "AWSInstanceType2Arch",
              _{
                Ref "AppType"
              },
              "Arch"
            ]
          }
        ]
      end
      KeyName do
        Ref "KeyName"
      end
      UserData do
        Fn__Base64 do
          Fn__Join [
            "",
            [
              "#!/bin/bash\n",
              "apt-get update\n",
              "env DEBIAN_FRONTEND=noninteractive apt-get install -y awscli chef python-setuptools\n",
              "easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz\n",
              "gem install librarian-chef\n",
              "mkdir -p /var/chef-solo\n",
              "function error_exit\n",
              "{\n",
              "  /usr/local/bin/cfn-signal -e 1 -r \"$1\" '", 
              _{ 
                Ref "AppWaitHandle" 
              }, 
              "'\n",
              "  exit 1\n",
              "}\n",
              "/usr/local/bin/cfn-init -s ",
              _{
                Ref "AWS::StackId"
              },
              " -r AppLaunchConfig ",
              "         --region ",
              _{
                Ref "AWS::Region"
              },
              " -c chef",
              "> /var/log/cfn-init.log || error_exit 'Failed to run cfn-init'\n",
              "/usr/local/bin/cfn-hup || error_exit 'Failed to start cfn-hup'\n",
              "chef-solo || error_exit 'Failed to bootstrap with chef-solo'\n",
              "/usr/local/bin/cfn-signal -e $? -r \"Instance bootstrap complete\" '",
              _{
                Ref "AppWaitHandle"
              },
              "'\n"
            ]
          ]
        end
      end
    end
  end
  AppWaitHandle do
    Type "AWS::CloudFormation::WaitConditionHandle"
  end
  AppWaitCondition do
    Type "AWS::CloudFormation::WaitCondition"
    DependsOn "AppGroup"
    Properties do
      Handle do
        Ref "AppWaitHandle"
      end
      Timeout 600
    end
  end
  SSHGroup do
    Type "AWS::EC2::SecurityGroup"
    Properties do
      GroupDescription "Enable SSH access"
      SecurityGroupIngress [
        _{
          IpProtocol "tcp"
          FromPort 22
          ToPort 22
          CidrIp do
            Ref "SSHLocation"
          end
        }
      ]
    end
  end
  AppGroup do
    Type "AWS::EC2::SecurityGroup"
    Properties do
      GroupDescription "Enable application access via port 8484"
      SecurityGroupIngress [
        _{
          IpProtocol "tcp"
          FromPort 8484
          ToPort 8484
          SourceSecurityGroupOwnerId "amazon-elb"
          SourceSecurityGroupName "amazon-elb-sg"
        }
      ]
    end
  end
end
Outputs do
  URL do
    Description "The DNS name used to access the application"
    Value do
      Fn__Join [ "",
      [
        "http://",
        _{ Fn__GetAtt "AppServerLB", "DNSName" } 
      ] ]
  end
end
end
