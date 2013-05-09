Description
===========

This cookbook deploys OTRS (Open Ticket Request System) through Chef.

Apache HTTPD is automatically installed an configured. 


Requirements
============

Platform
--------

* Debian, Ubuntu
* others untested, but could work

Cookbooks
---------

* perl
* apache2
* database
* mysql

Mail Server
-----------

Please install your preferred MTA (e.g. Postfix) on your own.


Attributes
==========

* `node['otrs']['version']` - Version of OTRS to deploy
* `node['otrs']['fqdn']` - Hostname used by OTRS
* `node['otrs']['prefix']` - File system path to install OTRS to (default `/usr/local`)

* `node['otrs']['kernel_config']['organization']` - Organization.
* `node['otrs']['kernel_config']['email']` - Admin email address.
* `node['otrs']['kernel_config']['system_id']` - System ID that should be more or less unique.

* `node['otrs']['database']['host']` - Database host default localhost 
* `node['otrs']['database']['user']` - Database user used by OTRS application
* `node['otrs']['database']['password']` - Database password by OTRS application
* `node['otrs']['database']['name']` - Database name
* `node['otrs']['database']['dba_user']` - Database dba user used for database creation
* `node['otrs']['database']['dba_password']` - Database dba password used for database create


Usage
=====

* If you modify the SysConfig through the OTRS user interface, make sure to export the new configuration and put it into `templates/host-otrs.example.com/SysConfig.pm`, as it will otherwise be overwritten or lost during an upgrade.
* Patch-level updates of OTRS should work flawlessly.

TODO
====

* HTTPS support for Apache
* Executing this cookbook requires two restarts at the moment:
 * First time it will fail in `RebuildConfiguration` as database is not configured, yet. Problem is that the MySQL part does not set up the database user quick enough. I've already [posted a question](http://lists.opscode.com/sympa/arc/chef/2012-01/msg00288.html) to the _chef_ mailing list, how to do this in a clean way. 
 * Next time (weird thing) the Apache restart command exits unclean, although everything is fine.
 * **I'm looking forward to your help on how to fix both of them!**


Change Log
==========

###0.9.0

* Initial version published
	
	
License and Authors
===================

Author:: Steffen Gebert <steffen.gebert@typo3.org>

Copyright:: 2012, Steffen Gebert / TYPO3 Association

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
