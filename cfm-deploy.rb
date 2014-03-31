#!/usr/bin/env ruby
#----------------------------------------------------------------------------
#
# NAME          : cfm-deploy.rb
#
# PURPOSE       : Deploy cloudformation stack to AWS
#
# DATE          : Mar 2014
#
# VERSION       : 1.1.0
#
# NOTES         : type ./cfm-deploy.rb -h for help
#
#----------------------------------------------------------------------------


require 'aws-sdk'
require 'json'
require 'optparse'

#Timeout for deletestack method in minutes
$deletion_timeout = 10

#Timeout for createstack method in minutes
$create_timeout = 60

#Timeout for updatestack method in minutes
$update_timeout = 120

# Method: createstack
def createstack(cfm,stackname,template,policy)
    puts "Creating stack #{stackname}!"
    cfm.client.create_stack(options = {
                            :stack_name => stackname,
                            :template_body => File.read(template),
                            :capabilities => ['CAPABILITY_IAM'],
                            :stack_policy_body => File.read(policy)
                            })
    
    # Wait for Stack deployment to complete
    counter = 0
    while (cfm.stacks[stackname].status == "CREATE_IN_PROGRESS") do
        counter+=1
        if counter > ($create_timeout*60/10)
            puts "Aborting - Timeout while creating"
            exit 1
        end
        sleep 10
    end
    
    # Abort if Stack creation fails
    if cfm.stacks[stackname].status != "CREATE_COMPLETE"
        puts "Failure - Stack creation unsuccessful"
        exit 1
    end
    puts "Stack created."
end

# Method: updatestack
def updatestack(cfm,stackname,template,policy)
    puts "Updating stack #{stackname}!"
    cfm.client.update_stack(options = {
                            :stack_name => stackname,
                            :template_body => File.read(template),
                            :capabilities => ['CAPABILITY_IAM'],
                            :stack_policy_body => File.read(policy)
                            })
    # Wait for Stack update to complete
    counter = 0
    while (cfm.stacks[stackname].status == "UPDATE_IN_PROGRESS") do
        counter+=1
        if counter > ($create_timeout*60/10)
            puts "Aborting - Timeout while updating"
            exit 1
        end
        sleep 10
    end
    
    # Abort if Stack update fails
    if cfm.stacks[stackname].status != "UPDATE_COMPLETE"
        puts "Failure - Stack update unsuccessful"
        exit 1
    end
    puts "Stack updated."
end

# Method: deletestack
def deletestack(cfm,stackname)
    puts "Deleting stack #{stackname}!"
    cfm.stacks[stackname].delete
    puts "Waiting deletion to finish ..."
    counter = 0
    while (cfm.stacks[stackname].exists? == true) do
        counter+=1
        if counter > ($deletion_timeout*60/5)
            puts "Aborting - Timeout while deleting"
            exit 1
        end
        sleep 5
    end
    puts "Stack deleted."
end


# Get command line options
ARGV << "-h" if ARGV.size != 10
options = {}
OptionParser.new do |opts|
    opts.banner = "Usage: cfm-deploy.rb [options]"
    opts.on("-n", "--name [STACK-NAME]", "AWS stack name") do |name|
        options[:name] = name
    end
    opts.on("-t", "--template [TEMPLATE-FILE]", "Cloudformation template file") do |template|
        options[:template] = template
    end
    opts.on("-k", "--accesskeyid [ACCESS-KEY]", "Your AWS access key") do |key|
        options[:key] = key
    end
    opts.on("-p", "--stackpolicy [POLICY-FILE]", "Stack policy file") do |policy|
        options[:policy] = policy
    end
    opts.on("-s", "--secretkey [SECRET-KEY]", "Your AWS secret key") do |secret|
        options[:secret] = secret
    end
    opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
    end
end.parse!

#Get an instance of the Cloudformation interface
cfm = AWS::CloudFormation.new(
                              :access_key_id => options[:key],
                              :secret_access_key => options[:secret],
                              :region => "eu-west-1")


# Execute action depending on stack status
if cfm.stacks[options[:name]].exists? == true
    status = cfm.stacks[options[:name]].status
    case status
        when "CREATE_COMPLETE"
        updatestack(cfm,options[:name],options[:template],options[:policy])
        when "UPDATE_COMPLETE"
        updatestack(cfm,options[:name])
        when "ROLLBACK_COMPLETE"
        deletestack(cfm,options[:name])
        createstack(cfm,options[:name],options[:template],options[:policy])
        when "UPDATE_ROLLBACK_COMPLETE"
        updatestack(cfm,options[:name],options[:template],options[:policy])
        when "ROLLBACK_IN_PROGRESS"
        deletestack(cfm,options[:name])
        createstack(cfm,options[:name],options[:template],options[:policy])
        when "DELETE_IN_PROGRESS"
        deletestack(cfm,options[:name])
        createstack(cfm,options[:name],options[:template],options[:policy])
        else
        puts "Stack not ready - Aborting (#{status})"
        exit 1
    end
else
    createstack(cfm,options[:name],options[:template],options[:policy])
end
    



