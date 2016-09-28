# Puppet Run Optimizer

## Description

These are rough and initial files used on Tranquilidade Desktop Linux project.
These allowed to largelly reduce puppet run cycle times (90-95% time reduction)

## Requirements

Perl
Database supported by DBI
Puppet Dashboard

## Technical

It uses "puppet_node_classifier" and analyzes puppet dashboard previous run reports and only applies previously unsuccessful or not ever run classes
There is a RESET interval at which an all classes run is trigered.

#### Files

Django models.py ( Database model )

Perl script that should be used has the puppet_node_classifier

#### Puppet tables:
2 tables for servers:
* Servers - simple host info
* ServerType - Servers aggregator

2 tables for puppet:
* PuppetModule - puppet module/class name and a filter that allows you to restrict it to a specific hostname (kind of Regular Expression, examples in models file).
* PuppetClass - aggregates hosts and/or servertypes and associates "PuppetModule" 's to these.

#### EXAMPLE (simplified):

ServerType
    ID=1
    Name=Servers_X
    Type=Image_20160101

Servers
    Name=server_1
    Type=1

    Name=server_2
    Type=1

PuppetModule
    ID=1
    Module=common::ntp
    OBS=Global NTP Config
    Filtro=server*

    ID=2
    Module=servers::ntp_server
    OBS=NTP Server 1 specific config
    Filtro=server_1

PuppetClass
    Name=Servers_X
    ServerType=1
    Modules=1
    Modules=2

Define 2 servers.
Define 2 Modules/Classes.
We apply both modules to Type Servers_X
Due to the filter servers::ntp_server is only applied to servidor_1.

The puppet_node_classifier should apply these:
once every 24h* (default interval on script)
    OR
if you change the updated_at in the PuppetModule record
    OR
if one didn't previously apply successfuly

#### Recommendation Puppet GIT repo
Use a commit message like:
-------------------
common::ntp
    Initial Commit

servers::ntp_server
    NTP Server Initial Config
-------------------
 
Then use a git commit hook to parse the classes and update the PuppetModule table, updated_at field with the current Timestamp

## Origin

This prototype was hacked in one afternoon.
It allowed us to be able to run puppet on atom cpu based computers.
I applied about 2800 modifications to each of the 200 computers, initially.
Previously, the run cycles would take > 20 minutes.
After this, a normal cycle would take 1-2 minutes.

When I left the project I was supporting about 800 computers.

## Improvements

There is a LOT to optimize from caching to bring it up to todays puppet infrastructure