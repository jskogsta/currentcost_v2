This directory holds information that is relevant for the MySQL database that persists all the data that the Currentcost daemon injects via WSO2DAS. A brief description is given below: 

currentcost_v2.sql : This is the table structure that is required for the Currentcost Perl daemon to operate. It has two table structures: one which is the raw event streams (which excludes the calculated watt_seconds), and the other includes the extension of the watt_seconds, which is required to calculate energy usage over a period of time. This calculation is done in the Perl daemon itself.
