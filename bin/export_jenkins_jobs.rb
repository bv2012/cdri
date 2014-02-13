require 'trollop'
require 'jenkins_api_client'

# using trollop to do command line options
opts = Trollop::options do
  opt :server, 'which Jenkins server to export from', :type => String, :required => true
  opt :repo, 'which git repo to replace', :type => String, :required => true
  opt :location, "which folder the jenkins job configuration should be exported to", :default => "/tmp/jenkins-jobs/"
end

unless  File.directory? opts[:location]
  Dir.mkdir(opts[:location])
end

client = JenkinsApi::Client.new(:server_url => opts[:server])
client.job.list_all.each do |job| 

  config = client.job.get_config job
  url_string = "<url>#{opts[:repo]}</url>" 
  tokenized_string = "<url><%= @source_repo %></url>"
  tokenized_config = config.gsub(url_string,tokenized_string)

  File.write("#{opts[:location]}/#{job}.xml.erb", tokenized_config)
end
