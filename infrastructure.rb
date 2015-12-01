AWSTemplateFormatVersion "2010-09-09"
Description "Creates and deployes 2 auto-scaling groups, one for an nginx load balancer and one for an app"
Parameters do
  KeyName do
    Description "Name of an EC2 keypair to enable SSH access"
    Type "String"
  end
  LBType do
    Description "Load balancer instance type"
    Type "String"
    Default "t1.micro"
    AllowedValues "t1.micro", "m1.small", "m1.medium", "m1.large", "m1.xlarge", "m2.xlarge", "m2.2xlarge", "m2.4xlarge", "m3.xlarge", "m3.2xlarge", "c1.medium", "c1.xlarge", "cc1.4xlarge", "cc2.8xlarge", "cg1.4xlarge"
    ConstraintDescription "must be a valid EC2 instance type."
  end
  AppType do
    Description "App instance type"
    Type "String"
    Default "t1.micro"
    AllowedValues "t1.micro", "m1.small", "m1.medium", "m1.large", "m1.xlarge", "m2.xlarge", "m2.2xlarge", "m2.4xlarge", "m3.xlarge", "m3.2xlarge", "c1.medium", "c1.xlarge", "cc1.4xlarge", "cc2.8xlarge", "cg1.4xlarge"
    ConstraintDescription "must be a valid EC2 instance type."
  end
  LBGroupSize do
    Default 1
    Description "The default number of EC2 instances for the load balancer cluster"
    Type "Number"
  end
  LBMaxSize do
    Default 1
    Description "The maximum number of EC2 instances for the load balancer cluster"
    Type "Number"
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
end
Mappings do
  AWSInstanceType2Arch(
    {"t2.micro"=>{"Arch"=>"64"},
     "t2.small"=>{"Arch"=>"64"},
     "t2.medium"=>{"Arch"=>"64"},
     "t2.large"=>{"Arch"=>"64"},
     "m4.large"=>{"Arch"=>"64"},
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
  LBServerGroup do
    Type "AWS::AutoScaling::AutoScalingGroup"
    Properties do
      LaunchConfigurationName do
        Ref "LBLaunchConfig"
      end
      AvailabilityZones do
        Fn__GetAZs do
          Ref "AWS::Region"
        end
      end
      MinSize 0
      MaxSize do
        Ref "LBMaxSize"
      end
      DesiredCapacity do
        Ref "LBGroupSize"
      end
    end
  end
  AppServerGroup do
    Type "AWS::AutoScaling::AutoScalingGroup"
    Properties do
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
  LaunchConfig do
    Type "AWS::AutoScaling::LaunchConfiguration"
    Metadata do
      AWS__CloudFormation__Init do
        configSets do
          order "collectSet", "fileSet", "commandSet"
        end
        collectSet do
          commands do
            collect_instances do
              command do
                Fn__Join [
                  "aws ec2 describe-instances --filters \"Name=tag:aws:autoscaling:groupName,Values=",
               _{ Ref "AppServerGroup" },
                  "\" \"Name=instance-state-name,Values=running\" | grep -o '\"i-[0-9a-f]\\+\"' | grep -o '[^\"]\\+'\" > /tmp/known_app_instances",
                  "\n"
                ]
              end
            end
          end
        end
        fileSet do
          files do
            _path("/etc/chef/solo.rb") do
              content do
                Fn__Join [
                  "\n",
                  "log_level :info", 
                  "log_location STDOUT", 
                  "file_cache_path \"/var/chef-solo\"", 
                  "cookbook_path \"/var/chef-solo/cookbooks\"", 
                  "json_attribs \"/etc/chef/node.json\"", 
                  "recipe_url \"https://github.com/cvlc/hello_world/archive/master.tar.gz\""
                ]
              end
              mode "000644"
              owner "root"
              group "wheel"
            end
            _path("/etc/chef/node.json") do
              content do
              end
              mode "000644"
              owner "root"
              group "wheel"
            end
          end
        end
        commandSet do
        end
      end
    end
    Properties do
      InstanceType do
        Ref "LBType"
      end
      SecurityGroups [
        _{
          Ref "SSHGroup"
        },
        _{
          Ref "LBGroup"
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
                Ref "FrontendType"
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
              "function error_exit\n",
              "{\n",
              "  /usr/local/bin/cfn-signal -e 1 -r \"$1\" '", { "Ref" : "WaitHandle" }, "'\n",
              "  exit 1\n",
              "}\n",
              "/usr/local/bin/cfn-init -s ",
              _{
                Ref "AWS::StackId"
              },
              " -r LBLaunchConfig ",
              "         --region ",
              _{
                Ref "AWS::Region"
              },
              "> /var/log/cfn-init.log || error_exit 'Failed to run cfn-init'\n",
              "/usr/local/bin/cfn-hup || error_exit 'Failed to start cfn-hup'\n",
              "chef-solo || error_exit 'Failed to bootstrap with chef-solo'\n",
              "/usr/local/bin/cfn-signal -e $? -r \"Instance bootstrap complete\" '",
              _{
                Ref "WaitHandle"
              },
              "'\n"
            ]
          ]
        end
      end
    end
  end
  WaitHandle do
    Type "AWS::CloudFormation::WaitConditionHandle"
  end
  WaitCondition do
    Type "AWS::CloudFormation::WaitCondition"
    DependsOn "LBGroup"
    Properties do
      Handle do
        Ref "WaitHandle"
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
  LBGroup do
    Type "AWS::EC2::SecurityGroup"
    Properties do
      GroupDescription "Enable HTTP access via port 80"
      SecurityGroupIngress [
        _{
          IpProtocol "tcp"
          FromPort 80
          ToPort 80
          CidrIp "0.0.0.0/0"
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
          SourceSecurityGroupName do
            Ref "LBGroup"
          end
        }
      ]
    end
  end
end
Outputs do
end
