require 'aws-sdk-core'

When(/^I lookup the OpsWorks stack for the local machine$/) do
  instance_id = `wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`
  region = `wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zon/.$//' 's/`
  puts "instance id: #{instance_id}"
  puts "region: #{region}"
  ec2 = Aws::EC2.new region: region
  
  @opsworks = Aws::OpsWorks.new region: "us-east-1"
  
  @stack = nil
  @opsworks.describe_stacks.stacks.each do |stack| 
    @opsworks.describe_instances(stack_id: stack.stack_id).instances.each do |instance| 
      if instance.ec2_instance_id == instance_id
        @stack = stack
        break
      end
    end
  end
end

Then(/^I should see a stack with one layer$/) do
  layers = @opsworks.describe_layers(stack_id: @stack.stack_id).layers.size
  expect(layers).to be(1), "The Jenkins stack should only have one layer, but has #{layers}"
end

Then(/^the layer should be named "(.*?)"$/) do |name|
  layer_name = @opsworks.describe_layers(stack_id: @stack.stack_id).layers.first.name
  
  expect(layer_name).to be(name), "The Jenkins stack should be #{name} but is actually #{layer_name}"
end

Then(/^I should see a layer with one instance$/) do
  layer_id = @opsworks.describe_layers(stack_id: @stack.stack_id).layers.first.layer_id
  instances = @opsworks.describe_instances(layer_id: layer_id).instances.size
  expect(instances).to be(1), "The Jenkins stack should only have one instance, but has #{instances}"
end

Then(/^the instance should be named "(.*?)"$/) do |name|
  layer_id = @opsworks.describe_layers(stack_id: @stack.stack_id).layers.first.layer_id
  instance_name = @opsworks.describe_instances(layer_id: layer_id).instances.first.name
  expect(instance_name).to be(name), "The Jenkins instance should be named #{name}, but is actually #{instance_name}"
end

Then(/^the instance should be running$/) do
  layer_id = @opsworks.describe_layers(stack_id: @stack.stack_id).layers.first.layer_id
  status = @opsworks.describe_instances(layer_id: layer_id).instances.first.status
  expect(status).to be("online"), "The Jenkins instance should be named online, but is actually #{status}"
end

