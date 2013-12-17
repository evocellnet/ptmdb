# ptmdb


This project contains all the necessary code to create and fill a database of post-translational modifications. The database will contain the quantitative and non-quatitative ptms available as well as the necessary information to map it through different IDs.

* Requirements:

Check out the config.sh file to be sure of the external databases necessary to fill the database.

* Dependencies:

	* perl - *packages:* DBI, DBD::MySQL, LWP

	* R - *packages:* RMySQL, (devtools?)

This repository can act also as a submodule of other projects intended to use the ptmdb.



### ptmdbR


ptmdbR has been created as a subproject of ptmdb and serves as an interface between the database and R. Some of the most frequent actions such as connecting with the database or querying its content are implemented as simple functions. This package serves as a framework that should be useful when asking higher order questions.


#####Using ptmdbR

Integrating ptmdbR on your on project is extremely easy. You just have to invoke the library from the proper path:

	library(ptmdbR, lib.loc="<path to the libraries parent directory>")


#####Updating ptmdbR

To add or modify ptmdbR functions, you can find the code for the whole package under ``src/ptmdbR/src``. Note that the package code is commented using [roxygen2](https://github.com/yihui/roxygen2). roxygen2 allows to produce the documentation for the different functions. Be kind a keep using it.

Once the code has been modified it's necessary to generate the updated documentation and build the package. In order to simplify this step, you can just run ``build_ptmdbR.sh`` on the main directory and the compiled ``ptmdbR`` packaged will be created on the location specified by ``PTMDBRLIBLOC`` on the ``config.sh``.