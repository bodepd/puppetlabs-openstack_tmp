# Puppet Module for Openstack

This module wraps the various other openstack modules and
provides higher level classes that can be used to deploy
openstack environments.

## Supported Versions

These modules are currently specific to the Essex release of OpenStack.

They have been tested and are known to work on Ubuntu 12.04 (Precise)

They are also in the process of being verified against Fedora 17.

## Usage

In order to use this module, it is necessary to checkout the git repos for the
modules that it depends on.

The rake task:

<pre>
  rake modules:clone_all
</pre>

Will check out all of the required modules based on the configuration in the file:

<pre>
  other_repos.yaml
</pre>

## Classes

This module currently provides 3 classes that can be used to deploy openstack.

openstack::all - can be used to deploy a single node all in one environemnt

openstack::controller - can be used to deploy an openstack controller

openstack::compute - can be used to deploy an openstack compute node.

## Example Usage

coming soon...
