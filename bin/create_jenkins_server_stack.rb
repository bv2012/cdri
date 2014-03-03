#Copyright (c) 2014 Stelligent Systems LLC
#
#MIT LICENSE
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.

$stdout.sync = true

require 'aws-sdk-core'
require 'trollop'

# we set up a CLoudFormation stack, and we need to know if it's done yet. These are the statuses indicating "not done yet"
PROGRESS_STATUSES = [ "CREATE_IN_PROGRESS",
  "ROLLBACK_IN_PROGRESS",
  "DELETE_IN_PROGRESS",
  "UPDATE_IN_PROGRESS",
  "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS",
  "UPDATE_ROLLBACK_IN_PROGRESS",
  "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS" ]

# checks to see if the cfn stack is done yet
def stack_in_progress cfn_stack_name
  status = @cfn.describe_stacks(stack_name: cfn_stack_name).stacks.first[:stack_status]
  return PROGRESS_STATUSES.include? status
end

# used to print status without newlines
def print_and_flush(str)
  print str
  $stdout.flush
end

# using trollop to do command line options
opts = Trollop::options do
  opt :region, 'The AWS region to use', :type => String, :default => "us-west-2"
  opt :zone, 'The AWS availability zone to use', :type => String, :default => "us-west-2a"
  opt :source, 'The github repo where the source to build resides (will not work with anything but github!)', :type => String, :default => "https://github.com/stelligent/canaryboard.git"
  opt :size, 'The instance size to use', :type => String, :default => "m1.large"
end


# alright, let's do this.
puts "You're creating a Jenkins instance in the #{opts[:region]} region. (size: #{opts[:size]})"
@timestamp = Time.now.strftime "%Y%m%d%H%M%S"

aws_region = opts[:region]
aws_az = opts[:zone]
instance_type = opts[:size]
# curious what the AWS calls look like? set http_wire_trace to true.
Aws.config = { region: aws_region, http_wire_trace: false }

# create a cfn stack with all the resources the opsworks stack will need
@cfn = Aws::CloudFormation.new 
cfn_stack_name = "Jenkins-Supporting-Resources-#{@timestamp}"
@cfn.create_stack stack_name: cfn_stack_name, template_body: File.open("./conf/jenkins_resources.template", "rb").read, capabilities: ["CAPABILITY_IAM"], timeout_in_minutes: 10

print_and_flush "creating required resources"
while (stack_in_progress cfn_stack_name)
  print_and_flush "."
  sleep 10
end
puts

# get the resource names out of the cfn stack so we can pass themto opsworks
resources = {}
@cfn.describe_stacks(stack_name: cfn_stack_name).stacks.first[:outputs].each do |output|
  resources[output[:output_key]] = output[:output_value]
end

jenkins_security_group = resources["JenkinsSecurityGroupOutput"]
ssh_security_group = resources["SSHSecurityGroupOutput"]
servicerolearn = resources["ServiceRoleOutput"]
ec2rolearn = resources["EC2RoleInstanceProfileOutput"]

# create the opsworks stack
ops = Aws::OpsWorks.new region: "us-east-1"

# opsworks configuration is passed in as json
custom_json = <<END
  { 
      "rvm": {
          "user_installs": [
              {
                  "user": "jenkins"
              }
          ],
          "version": "1.22.19",
          "user_home_root": "/var/lib",
          "global_gems": [
              {
                  "name": "trollop",
                  "version": "2.0"
              },
              {
                  "name": "aws-sdk-core",
                  "version": "2.0.0.rc2"
              }
          ]
      },
      "pipeline": {
        "source" : "#{opts[:source]}",
        "jobs" : [ "trigger-stage", "commit-stage", "acceptance-stage", "capacity-stage", "exploratory-stage", "preproduction-stage", "production-stage", "jenkins-test" ]
      },

      "jenkins": {
          "notifications": {
              "enabled": "false"
          },
          "http_proxy": {
            "variant" : "apache2"
          },
          "server": {
            "plugins" : [
                     { "name" : "analysis-core",                 "version" : "1.38"    },
                     { "name" : "ansicolor",                     "version" : "0.3.1"   },
                     { "name" : "audit-trail",                   "version" : "1.8"     },
                     { "name" : "brakeman",                      "version" : "0.7"     },
                     { "name" : "build-pipeline-plugin",         "version" : "1.4"     },
                     { "name" : "buildresult-trigger",           "version" : "0.10"    },
                     { "name" : "conditional-buildstep",         "version" : "1.3.1"   },
                     { "name" : "config-file-provider",          "version" : "2.6.2"   },
                     { "name" : "configurationslicing",          "version" : "1.38.3"  },
                     { "name" : "cucumber-reports",              "version" : "0.0.21"  },
                     { "name" : "delivery-pipeline-plugin",      "version" : "0.6.10"  }, 
                     { "name" : "email-ext",                     "version" : "2.35.1"  }, 
                     { "name" : "envinject",                     "version" : "1.89"    },
                     { "name" : "fstrigger",                     "version" : "0.34"    },
                     { "name" : "git",                           "version" : "1.4.0"   },
                     { "name" : "git-client",                    "version" : "1.0.6"   },
                     { "name" : "github",                        "version" : "1.8"     },
                     { "name" : "github-api",                    "version" : "1.44"    },
                     { "name" : "groovy",                        "version" : "1.14"    },
                     { "name" : "groovy-postbuild",              "version" : "1.8"     },
                     { "name" : "htmlpublisher",                 "version" : "1.2"     },
                     { "name" : "ivytrigger",                    "version" : "0.26"    },
                     { "name" : "jenkins-cloudformation-plugin", "version" : "0.11"    },
                     { "name" : "job-exporter" ,                 "version" : "0.4"     },
                     { "name" : "jquery",                        "version" : "1.7.2-1" },
                     { "name" : "log-parser",                    "version" : "1.0.8"   },
                     { "name" : "managed-scripts" ,              "version" : "1.1"     }, 
                     { "name" : "multiple-scms",                 "version" : "0.2"     },
                     { "name" : "parameterized-trigger",         "version" : "2.20"    },
                     { "name" : "postbuildscript",               "version" : "0.14"    },
                     { "name" : "rake",                          "version" : "1.7.8"   },
                     { "name" : "ruby-runtime",                  "version" : "0.12"    },
                     { "name" : "rubyMetrics",                   "version" : "1.5.0"   },
                     { "name" : "run-condition",                 "version" : "0.10"    },
                     { "name" : "rvm",                           "version" : "0.4"     },
                     { "name" : "scripttrigger",                 "version" : "0.28"    },
                     { "name" : "token-macro",                   "version" : "1.6"     },
                     { "name" : "urltrigger",                    "version" : "0.31"    },
                     { "name" : "ws-cleanup",                    "version" : "0.18"    },
                     { "name" : "xtrigger",                      "version" : "0.54"    }
                    ],

              "install_method": "package",
              "version": "1.543-1.1"
          },
          "node": {
            "executors": 8
          }
      }
  }
END



# create a new opsworks stack
stack_params = {
  name: "Jenkins Server #{@timestamp}", 
  region: aws_region, 
  default_os: 'Amazon Linux',
  service_role_arn: servicerolearn,
  default_instance_profile_arn: ec2rolearn,
  custom_json: custom_json,
  use_custom_cookbooks: true,
  custom_cookbooks_source: {
      type: 'git',
      url: 'https://github.com/stelligent/jenkins_chef_cookbooks.git',
#      revision: 'dev'
    }
}

# detect whether or not the account has a default VPC set up. If so, use that.
@ec2 = Aws::EC2.new
default_vpc = @ec2.describe_account_attributes(attribute_names: ["default-vpc"]) == "none"
if default_vpc
  stack_params[:vpc_id] = @ec2.describe_account_attributes(attribute_names: ["default-vpc"]).account_attributes.first.attribute_values.first.attribute_value
end

# opsworks is "regionless" but really "only in us-east-1"
Aws.config = { region: "us-east-1", http_wire_trace: false }

puts "creating OpsWorks stack..."
stack = ops.create_stack stack_params

# create layer for Jenkins
layer_params = {
  stack_id: stack.stack_id, 
  type: 'custom',
  name: 'Jenkins Server Layer',
  shortname: 'jenkins',
  custom_security_group_ids: [ jenkins_security_group, ssh_security_group ],
  packages: %w{readline-devel libyaml-devel libffi-devel mlocate},
  custom_recipes: { setup: %w{ jenkins::server jenkins::proxy rvm::user_install jenkins-configuration::jobs jenkins-configuration::views opsworks_nodejs } }
}

puts "creating OpsWorks layer..."
layer = ops.create_layer layer_params

# create jenkins instance
instance_params = {
  stack_id: stack.stack_id,
  layer_ids: [layer.layer_id],
  instance_type: instance_type,
  hostname: "jenkins",
# SSHing into OpsWorks stacks isn't recommended, so by default, you can't.
# If you want to, though, you can set your SSH keyname here and then you'll be able to get in.
# SSH Key must already exist, and must be in the same region as the instance.
#
#  ssh_key_name: "keyname here",
  install_updates_on_boot: true,
  availability_zone: aws_az,
  architecture: 'x86_64',
  root_device_type: "ebs"
}

puts "creating OpsWorks instance..."
instance = ops.create_instance instance_params

# start the instance and if the start command succeeds, we're good. It'll take a good while for the instance to boot up, tho.
ops.start_instance instance_id: instance.instance_id
puts "Instance started. It's now running the configuration and should be up in about 15-45 minutes, depending on instance size."
