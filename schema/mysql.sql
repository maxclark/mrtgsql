/*
 * mysql.sql
 *
 *  Copyright (C) 2004 Max Clark and Creative Thought Inc.
 *
 *  This will create tables for use in storing MRTG data. The scripts default to
 *  'mrtg', but you can run this in the database of your choice and modify the
 *  scripts.
 *
 *  This will work with MySQL.
 *
 */

--
-- Table structure for table `interface`
--

CREATE TABLE interface (
  id int(10) unsigned NOT NULL auto_increment,
  interface varchar(100) NOT NULL default '',
  description varchar(255) NOT NULL default '',
  active char(1) NOT NULL default '1',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `mrtglog`
--

CREATE TABLE mrtglog (
  id int(10) unsigned NOT NULL auto_increment,
  interfaceid int(10) unsigned NOT NULL default '0',
  date int(11) unsigned NOT NULL default '0',
  avgin int(10) unsigned NOT NULL default '0',
  avgout int(10) unsigned NOT NULL default '0',
  peakin int(10) unsigned NOT NULL default '0',
  peakout int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (id)
) TYPE=MyISAM;
