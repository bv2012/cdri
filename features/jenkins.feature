@jenkins
Feature: Scripted install of Jenkins
    As a continuous delivery engineer
    I would like Jenkins to be installed and configured correctly
    so that that my Jenkins server will work as expected

    Background:
        Given I am sshed into the Jenkins environment

    Scenario: Is java 6 installed and set as the default java?
        When I run "java -version"
        Then I should see "java version "1.6.0_29""

    Scenario: Is Jenkins installed and version 1.447.1
        When I run "md5sum slave.jar"
        Then I should see "21dc5351fb75d42045be52cd28971337"

    Scenario: Is Jenkins set to run on startup
        When I run "/sbin/chkconfig --list jenkins_agent"
        Then I should see "3:on"

    Scenario: Is Jenkins currently running
        When I run "/sbin/service jenkins_agent status"
        Then I should see "is running"
    
    Scenario: Is ruby 1.9.3 installed
        When I run "sudo -i -u jenkins rvm list"
        Then I should see "ruby-1.9.3"

