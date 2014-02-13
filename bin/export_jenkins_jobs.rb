# using trollop to do command line options
opts = Trollop::options do
  opt :server, 'The AWS region to use', :type => String, :default => "us-west-2"
  opt :repo, 'The AWS availability zone to use', :type => String, :default => "us-west-2a"
  opt :location, "which folder the jenkins job configuration should be exported to", default => "/tmp/jenkins-jobs/"
end

# export all the jobs off the server
# remove github repo from each job
client = JenkinsApi::Client.new(:server_url => opts[:server])
client.job.list_all.each do |job| 

  config = client.job.get_config job
  url_string = "<url>#{opts[:repo]}</url>" 
  tokenized_string = "<url><%= @source_repo %></url>"
  tokenized_config = config.gsub(url_string,tokenized_string)

  File.write("#{opts[:location]}/#{job}.xml.erb", tokenized_config)
end
