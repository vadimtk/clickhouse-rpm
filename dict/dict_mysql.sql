CREATE TABLE `dict` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(256) DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;


insert into dict set code='gbp', name='pound';
insert into dict set code='rur', name='rouble';
insert into dict set code='usd', name='dollar';
insert into dict set code='eur', name='euro';

