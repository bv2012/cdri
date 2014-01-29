@jenkins
Feature: Scripted install of Jenkins
    As a continuous delivery engineer
    I would like Jenkins to be installed and configured correctly
    so that that my Jenkins server will work as expected

    Background:
        Given I am testing the local environment

    Scenario: Is the hostname set correctly?
        When I run "hostname"
        Then I should see "jenkins"

    Scenario: Is ruby 1.9.3 installed
        When I run "ruby -v"
        Then I should see "ruby 2.0.0"

    Scenario: Is the server listening on port 80?
        When I run "netstat -antu | grep 80"
        Then I should see ":::80"

    Scenario: Is Jenkins installed?
        When I run "ls /var/lib/jenkins/"
        Then I should see "config.xml"
        When I run "service jenkins status"
        Then I should see "is running..."

    Scenario: Are the pipeline jobs present?
        When I run "ls /var/lib/jenkins/jobs"
        Then I should see "acceptance-stage"
        Then I should see "capacity-stage"
        Then I should see "commit-stage"
        Then I should see "exploratory-stage"
        Then I should see "preproduction-stage"
        Then I should see "production-stage"
        Then I should see "trigger-stage"
