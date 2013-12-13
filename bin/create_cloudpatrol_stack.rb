$stdout.sync = true

require 'aws-sdk-core'
require 'pp'
require 'trollop'

opts = Trollop::options do
  opt :region, 'The AWS region to use', :type => String, :default => "us-west-2"
  opt :instance_type, 'The type of AWS EC2 instance to use', :type => String, :default => "c3.large"
  opt :availability_zone, 'The availability zone to use', :type => String, :default => "us-west-2a"
  opt :security_group, 'The identifier of the security group to use (ie. sg-0ef5c53e)', :type => String, :default => "sg-0ef5c53e"
  opt :ssh_key_name, 'The ssh keypair to use to connect to the instance (without the .pem)', :type => String, :default => "jonny-labs-west2"
  opt :wait, "Whether or not to wait for the stack's instances to come up before the script completes", :default => true, :type => :boolean
end

ssh_key_name = opts[:ssh_key_name]
aws_region = opts[:region]
aws_az = opts[:availability_zone]
instance_type = opts[:instance_type]
security_group = opts[:security_group]
Aws.config = { region: 'us-east-1' }

ops = Aws::OpsWorks.new 

custom_json = <<END
{
    "app_name": "cloudpatrol",
    "deploy": {
        "cloudpatrol": {
            "database": {
                "adapter": "sqlite3",
                "database": "/home/deploy/cloudpatrol.db",
                "pool": "5",
                "timeout": "5000"
            },
            "migrate": true
        }
    }
}
END


s3 = Aws::S3.new region: 'us-east-1'
response = s3.get_object bucket: "stelligent-pem-files", key: "github-cloudpatrol.pem"

stack_params = {
  name: "Jonny's CloudPatrol Server", 
  region: aws_region, 
  service_role_arn: 'arn:aws:iam::324320755747:role/aws-opsworks-service-role', 
  default_instance_profile_arn: 'arn:aws:iam::324320755747:instance-profile/aws-opsworks-ec2-role',
  custom_json: custom_json,
  default_os: 'Amazon Linux',
  use_custom_cookbooks: true,
  custom_cookbooks_source: {
      type: 'git',
      url: 'git@github.com:stelligent/cloudpatrol_chefrepo',
      ssh_key:  response.body.string
    }
}

stack = ops.create_stack stack_params
# pp stack

layer_params = {
  stack_id: stack.stack_id, 
  type: 'rails-app',
  name: 'CloudPatrol Rails Layer',
  shortname: 'cloudpatrol',
  custom_security_group_ids: [ security_group ],
  packages: [ "mlocate" ],
  :auto_assign_elastic_ips => false,
  :auto_assign_public_ips => true,
  custom_recipes: {
      # deploy: %w{rails_config cloudpatrol}
      deploy: %w{rails_config}
  },
  attributes: {
      "BundlerVersion" => "1.3.5",
      "PassengerVersion" => "4.0.19",
      "RailsStack" => "apache_passenger",
      "RubyVersion" => "1.9.3",
      "RubygemsVersion" => "2.1.7"
  }
}

layer = ops.create_layer layer_params
# pp layer

instance_params = {
  stack_id: stack.stack_id,
  layer_ids: [layer.layer_id],
  instance_type: instance_type,
  hostname: "cloudpatrol",
  ssh_key_name: ssh_key_name,
  install_updates_on_boot: true,
  availability_zone: aws_az,
  architecture: 'x86_64',

}

instance = ops.create_instance instance_params
# pp instance

app_params = {

  stack_id: stack.stack_id,
  name: "cloudpatrol",
  type: "rails",
  app_source: {
      type: 'git',
      url: 'https://github.com/stelligent/cloudpatrol.git',
  },
  attributes: {
      'AutoBundleOnDeploy' => 'true',
      'DocumentRoot' => 'public',
      'RailsEnv' => 'staging'
  }
}

app = ops.create_app app_params

ops.start_instance instance_id: instance.instance_id

online = false
while (opts[:wait] and !online)
  response = ops.describe_instances stack_id: stack.stack_id
  response.instances.each do |i|
      puts "instance status: #{i.status}"
      if %w{setup_failed start_failed terminating terminated connection_lost}.include?(i.status)
        raise "The instance #{instance_id} could not start."
      elsif %w{online}.include?(i.status)
        online = true
      end
      sleep 30
  end
end

File.open("stack_id", 'w') {|f| f.write(stack_id) }