$stdout.sync = true

require 'aws-sdk-core'
require 'pp'
require 'trollop'

SUCCESS_STATUSES =  [ "CREATE_COMPLETE",
  "UPDATE_COMPLETE" ]

FAILURE_STATUSES =  [ "CREATE_FAILED",
  "ROLLBACK_FAILED",
  "ROLLBACK_COMPLETE",
  "DELETE_FAILED",
  "UPDATE_ROLLBACK_FAILED",
  "UPDATE_ROLLBACK_COMPLETE",
  "DELETE_COMPLETE" ]

PROGRESS_STATUSES = [ "CREATE_IN_PROGRESS",
  "ROLLBACK_IN_PROGRESS",
  "DELETE_IN_PROGRESS",
  "UPDATE_IN_PROGRESS",
  "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS",
  "UPDATE_ROLLBACK_IN_PROGRESS",
  "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS" ]

def stack_in_progress cfn_stack_name
  status = @cfn.describe_stacks(stack_name: cfn_stack_name).stacks.first[:stack_status]
  return PROGRESS_STATUSES.include? status
end

# def create_ec2_keypair
#   name = "jenkins-key-pair-#{@timestamp}"
#   ec2 = Aws::EC2.new 
#   ec2.create_key_pair key_name: name
#   return name
# end

def print_and_flush(str)
  print str
  $stdout.flush
end

opts = Trollop::options do
  opt :region, 'The AWS region to use', :type => String, :default => "us-west-2"
  opt :zone, 'The AWS availability zone to use', :type => String, :default => "us-west-2a"
  opt :size, 'The instance size to use', :type => String, :default => "c3.large"
end

puts "You're creating a Jenkins instance in the #{opts[:region]} region. (size: #{opts[:size]})"
@timestamp = Time.now.strftime "%Y%m%d%H%M%S"

aws_region = opts[:region]
aws_az = opts[:zone]
instance_type = opts[:size]
Aws.config = { region: aws_region, http_wire_trace: false }

@cfn = Aws::CloudFormation.new 
cfn_stack_name = "Jenkins-Supporting-Resources-#{@timestamp}"
@cfn.create_stack stack_name: cfn_stack_name, template_body: File.open("./conf/jenkins_resources.template", "rb").read, capabilities: ["CAPABILITY_IAM"], timeout_in_minutes: 10

print_and_flush "creating required resources"
while (stack_in_progress cfn_stack_name)
  print_and_flush "."
  sleep 10
end

puts

resources = {}
@cfn.describe_stacks(stack_name: cfn_stack_name).stacks.first[:outputs].each do |output|
  resources[output[:output_key]] = output[:output_value]
end

jenkins_security_group = resources["JenkinsSecurityGroupOutput"]
ssh_security_group = resources["SSHSecurityGroupOutput"]
servicerolearn = resources["ServiceRoleOutput"]
ec2rolearn = resources["EC2RoleOutput"]

# ssh_key_name = create_ec2_keypair

ops = Aws::OpsWorks.new region: "us-east-1"

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

stack_params = {
  name: "Jenkins Server #{@timestamp}", 
  region: aws_region, 
  default_os: 'Amazon Linux',
  service_role_arn: 'arn:aws:iam::324320755747:role/aws-opsworks-service-role', 
  default_instance_profile_arn: 'arn:aws:iam::324320755747:instance-profile/jenkins',
  custom_json: custom_json,
  use_custom_cookbooks: true,
  custom_cookbooks_source: {
      type: 'git',
      url: 'https://github.com/stelligent/jenkins_chef_cookbooks.git'
    }
}

Aws.config = { region: "us-east-1", http_wire_trace: false }

puts "creating OpsWorks stack..."
stack = ops.create_stack stack_params
# pp stack

layer_params = {
  stack_id: stack.stack_id, 
  type: 'custom',
  name: 'Jenkins Server Layer',
  shortname: 'jenkins',
  custom_security_group_ids: [ jenkins_security_group, ssh_security_group ],
  packages: %w{readline-devel libyaml-devel libffi-devel mlocate},
  custom_recipes: { setup: %w{firefox jenkins::server jenkins::proxy rvm::user_install jenkins-configuration::jobs jenkins-configuration::views} }
}

puts "creating OpsWorks layer..."
layer = ops.create_layer layer_params
# pp layer

instance_params = {
  stack_id: stack.stack_id,
  layer_ids: [layer.layer_id],
  instance_type: instance_type,
  hostname: "jenkins",
  # ssh_key_name: ssh_key_name,
  install_updates_on_boot: true,
  availability_zone: aws_az,
  architecture: 'x86_64',
  root_device_type: "ebs"
}

puts "creating OpsWorks instance..."
instance = ops.create_instance instance_params
# pp instance

ops.start_instance instance_id: instance.instance_id
puts "Instance started. It's now running the configuration and should be up in about 30 minutes, give or take."
